class AutoVerifyDocumentsFor2025Sellers < ActiveRecord::Migration[7.1]
  def up
    # Update legacy document_verified field on sellers table for 2025 sellers
    sellers_updated = execute(<<-SQL.squish
      UPDATE sellers
      SET document_verified = true
      WHERE EXTRACT(YEAR FROM created_at) = 2025
        AND document_url IS NOT NULL
        AND document_url != ''
        AND document_verified = false
    SQL
    )
    
    Rails.logger.info "✅ Updated #{sellers_updated.cmd_tuples} sellers with legacy document verification"
    
    # Update seller_documents table for all documents belonging to 2025 sellers
    documents_updated = execute(<<-SQL.squish
      UPDATE seller_documents
      SET document_verified = true
      WHERE seller_id IN (
        SELECT id FROM sellers WHERE EXTRACT(YEAR FROM created_at) = 2025
      )
      AND document_verified = false
    SQL
    )
    
    Rails.logger.info "✅ Updated #{documents_updated.cmd_tuples} seller documents with verification"
  end

  def down
    # Note: We don't reverse this as it's a one-time data fix
    # If needed, you can manually unverify documents
  end
end
