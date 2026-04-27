class Admin::MonitoringController < ApplicationController
  before_action :authenticate_admin

  # GET /admin/monitoring
  def index
    @error_summary = MonitoringService.get_error_summary(24.hours)
    @metric_summary = MonitoringService.get_metric_summary(24.hours)
    @recent_errors = MonitoringError.where('created_at > ?', 24.hours.ago)
                                   .order(created_at: :desc)
                                   .limit(50)
    @unresolved_count = MonitoringError.where(resolved_at: nil).count
    @total_errors_today = MonitoringError.where('created_at > ?', 24.hours.ago).count

    render json: {
      error_summary: @error_summary,
      metric_summary: @metric_summary,
      recent_errors: @recent_errors.map(&:to_json_with_context),
      stats: {
        unresolved_errors: @unresolved_count,
        total_errors_today: @total_errors_today,
        uptime: calculate_uptime,
        health_check: health_status
      }
    }
  end

  # GET /admin/monitoring/errors
  def errors
    errors = MonitoringError.includes(:context)
                            .order(created_at: :desc)
                            .page(params[:page])
                            .per(50)

    render json: {
      errors: errors.map(&:to_json_with_context),
      pagination: {
        current_page: errors.current_page,
        total_pages: errors.total_pages,
        total_count: errors.total_count
      }
    }
  end

  # POST /admin/monitoring/resolve_error
  def resolve_error
    error = MonitoringService.resolve_error(params[:id])
    render json: { message: 'Error resolved', error: error.to_json_with_context }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Error not found' }, status: :not_found
  end

  # GET /admin/monitoring/metrics
  def metrics
    timeframe = params[:timeframe]&.to_i || 24
    metrics = MonitoringMetric.where('created_at > ?', timeframe.hours.ago)
                           .order(timestamp: :desc)
                           .limit(1000)

    render json: {
      metrics: metrics.map(&:to_json_with_tags),
      summary: MonitoringService.get_metric_summary(timeframe.hours)
    }
  end

  # GET /admin/monitoring/health
  def health
    render json: {
      status: health_status,
      checks: {
        database: check_database,
        redis: check_redis,
        sidekiq: check_sidekiq,
        disk_space: check_disk_space,
        memory: check_memory
      },
      timestamp: Time.current
    }
  end

  private

  def authenticate_admin
    @current_user = AdminAuthorizeApiRequest.new(request.headers).result
    unless @current_user && @current_user.is_a?(Admin)
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def calculate_uptime
    # Simple uptime calculation - in production, you'd want to track this properly
    start_time = Rails.cache.read('app_start_time') || Time.current
    ((Time.current - start_time) / 1.hour).round(2)
  end

  def check_database
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      { status: 'ok', message: 'Database connection successful' }
    rescue => e
      { status: 'error', message: "Database connection failed: #{e.message}" }
    end
  end

  def check_redis
    begin
      # Redis gem v5 removed Redis.current — use the app's own connection pool
      RedisConnection.with { |conn| conn.ping }
      { status: 'ok', message: 'Redis connection successful' }
    rescue => e
      { status: 'error', message: "Redis connection failed: #{e.message}" }
    end
  end

  def check_sidekiq
    begin
      # sidekiq/api must be explicitly required — it is not auto-loaded
      require 'sidekiq/api'
      stats = Sidekiq::Stats.new
      {
        status: 'ok',
        message: "Sidekiq running (#{stats.processes_size} process#{stats.processes_size == 1 ? '' : 'es'})",
        data: {
          workers:   stats.workers_size,
          processes: stats.processes_size,
          enqueued:  stats.enqueued,
          failed:    stats.failed
        }
      }
    rescue LoadError
      { status: 'warning', message: 'Sidekiq gem not available in this environment' }
    rescue => e
      { status: 'error', message: "Sidekiq check failed: #{e.message}" }
    end
  end

  def check_disk_space
    begin
      # Inside Dokploy Docker containers df / reports the overlay filesystem —
      # this is intentional and gives correct container disk usage.
      df_output = `df -k / | tail -1`
      if $?.success?
        parts = df_output.split
        # df -k columns: Filesystem, 1K-blocks, Used, Available, Use%, Mounted
        total_kb    = parts[1].to_i
        used_kb     = parts[2].to_i
        used_pct    = total_kb > 0 ? (used_kb * 100 / total_kb) : 0
        total_gb    = (total_kb / 1_048_576.0).round(1)
        used_gb     = (used_kb  / 1_048_576.0).round(1)
        status      = used_pct > 90 ? 'error' : used_pct > 80 ? 'warning' : 'ok'
        {
          status: status,
          message: "Container disk: #{used_pct}% used (#{used_gb} GB / #{total_gb} GB)",
          data: { used_percent: used_pct, used_gb: used_gb, total_gb: total_gb }
        }
      else
        { status: 'error', message: 'Could not check disk space' }
      end
    rescue => e
      { status: 'error', message: "Disk check failed: #{e.message}" }
    end
  end

  def check_memory
    begin
      # Prefer /proc/meminfo — works on Linux and inside Dokploy Docker containers.
      # Respects cgroup memory limits (Docker --memory) when /sys/fs/cgroup is mounted.
      if File.exist?('/proc/meminfo')
        meminfo = File.read('/proc/meminfo')

        # Try cgroup v2 memory limit first (Dokploy uses Docker with cgroups)
        cgroup_limit_file  = '/sys/fs/cgroup/memory.max'
        cgroup_usage_file  = '/sys/fs/cgroup/memory.current'
        cgroup_v1_limit    = '/sys/fs/cgroup/memory/memory.limit_in_bytes'
        cgroup_v1_usage    = '/sys/fs/cgroup/memory/memory.usage_in_bytes'

        limit_bytes = nil
        used_bytes  = nil

        if File.exist?(cgroup_limit_file)
          raw = File.read(cgroup_limit_file).strip
          limit_bytes = raw == 'max' ? nil : raw.to_i
          used_bytes  = File.exist?(cgroup_usage_file) ? File.read(cgroup_usage_file).strip.to_i : nil
        elsif File.exist?(cgroup_v1_limit)
          limit_bytes = File.read(cgroup_v1_limit).strip.to_i
          # cgroup v1 limit of ~9.2EB means "no limit" — ignore
          limit_bytes = nil if limit_bytes > 1_000_000_000_000
          used_bytes  = File.exist?(cgroup_v1_usage) ? File.read(cgroup_v1_usage).strip.to_i : nil
        end

        if limit_bytes && used_bytes
          # Container has an explicit memory limit set in Dokploy
          total_mb = (limit_bytes / 1_048_576.0).round
          used_mb  = (used_bytes  / 1_048_576.0).round
          source   = 'container limit'
        else
          # Fall back to host memory from /proc/meminfo
          total_kb = meminfo[/MemTotal:\s+(\d+)/, 1].to_i
          avail_kb = meminfo[/MemAvailable:\s+(\d+)/, 1].to_i
          used_kb  = total_kb - avail_kb
          total_mb = (total_kb / 1024.0).round
          used_mb  = (used_kb  / 1024.0).round
          source   = 'host'
        end

        used_pct = total_mb > 0 ? (used_mb * 100 / total_mb) : 0
        status   = used_pct > 90 ? 'error' : used_pct > 75 ? 'warning' : 'ok'
        {
          status: status,
          message: "Memory (#{source}): #{used_mb} MB / #{total_mb} MB (#{used_pct}% used)",
          data: { used_mb: used_mb, total_mb: total_mb, used_pct: used_pct, source: source }
        }

      elsif RUBY_PLATFORM.include?('darwin')
        # Local macOS dev only — not used in Dokploy production
        vm = `vm_stat`
        page_size = 4096
        pages = {}
        vm.each_line do |line|
          pages[:free]     = $1.to_i if line =~ /Pages free:\s+(\d+)/
          pages[:active]   = $1.to_i if line =~ /Pages active:\s+(\d+)/
          pages[:wired]    = $1.to_i if line =~ /Pages wired down:\s+(\d+)/
        end
        total_pages = pages.values.sum + (pages[:free] || 0)
        used_pages  = (pages[:active] || 0) + (pages[:wired] || 0)
        used_pct    = total_pages > 0 ? (used_pages * 100 / total_pages) : 0
        total_mb    = (total_pages * page_size / 1_048_576).round
        used_mb     = (used_pages  * page_size / 1_048_576).round
        status      = used_pct > 90 ? 'error' : used_pct > 75 ? 'warning' : 'ok'
        { status: status, message: "Memory (macOS): #{used_mb} MB / #{total_mb} MB (#{used_pct}% used)",
          data: { used_mb: used_mb, total_mb: total_mb, used_pct: used_pct, source: 'macOS' } }
      else
        { status: 'warning', message: 'Memory info unavailable on this platform' }
      end
    rescue => e
      { status: 'warning', message: "Memory check unavailable: #{e.message}" }
    end
  end

  def health_status
    checks = [check_database, check_redis, check_sidekiq, check_disk_space, check_memory]
    if checks.all? { |c| c[:status] == 'ok' }
      'ok'
    elsif checks.any? { |c| c[:status] == 'error' }
      'error'
    else
      'warning'
    end
  end
end
