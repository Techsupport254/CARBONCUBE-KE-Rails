# backend/lib/scripts/generate_pantech_html.rb
require 'csv'
require 'erb'

csv_path = "tmp/pantech_ads_20260221_105301.csv"
html_path = "tmp/pantech_product_catalog.html"

unless File.exist?(csv_path)
  puts "Error: CSV file not found at #{csv_path}"
  exit
end

products = []
CSV.foreach(csv_path, headers: true) do |row|
  products << row.to_h
end

template = %q{
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pantech Kenya Limited - Product Catalog</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #0056b3;
            --secondary: #6c757d;
            --accent: #e9ecef;
            --text-dark: #212529;
            --text-light: #495057;
            --white: #ffffff;
            --border: #dee2e6;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Inter', sans-serif;
            background-color: #f8f9fa;
            color: var(--text-dark);
            line-height: 1.6;
            padding: 40px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: var(--white);
            padding: 40px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.05);
            border-radius: 8px;
        }

        header {
            text-align: center;
            margin-bottom: 50px;
            border-bottom: 2px solid var(--primary);
            padding-bottom: 20px;
        }

        header h1 {
            color: var(--primary);
            font-size: 32px;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        header p {
            color: var(--secondary);
            font-size: 16px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }

        th {
            background-color: var(--primary);
            color: var(--white);
            text-align: left;
            padding: 15px;
            font-weight: 600;
            font-size: 14px;
            position: sticky;
            top: 0;
        }

        td {
            padding: 15px;
            border-bottom: 1px solid var(--border);
            vertical-align: top;
            font-size: 13px;
        }

        tr:nth-child(even) {
            background-color: #fcfcfc;
        }

        tr:hover {
            background-color: #f1f8ff;
        }

        .img-cell {
            width: 100px;
        }

        .product-img {
            width: 80px;
            height: 80px;
            object-fit: contain;
            border-radius: 4px;
            border: 1px solid var(--border);
            background: #fff;
        }

        .price {
            font-weight: 700;
            color: var(--primary);
            white-space: nowrap;
        }

        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            background: var(--accent);
            color: var(--text-light);
            margin-bottom: 5px;
        }

        .desc {
            max-width: 400px;
            white-space: pre-line;
            color: var(--text-light);
            font-size: 12px;
        }

        .id-cell { color: var(--secondary); font-family: monospace; }
        
        .footer {
            margin-top: 40px;
            text-align: center;
            color: var(--secondary);
            font-size: 12px;
        }

        .view-link {
            display: inline-block;
            margin-top: 10px;
            padding: 6px 12px;
            background-color: var(--white);
            color: var(--primary);
            border: 1px solid var(--primary);
            text-decoration: none;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            transition: all 0.2s;
        }

        .view-link:hover {
            background-color: var(--primary);
            color: var(--white);
        }

        .num-cell {
            width: 40px;
            color: var(--secondary);
            font-weight: 600;
        }

        @media print {
            body { background: none; padding: 0; }
            .container { box-shadow: none; width: 100%; max-width: 100%; padding: 0; }
            th { background-color: #eeeeee !important; color: #000 !important; }
            .no-print { display: none; }
            .view-link { border: none; padding: 0; color: var(--primary); }
            table { page-break-inside: auto; }
            tr { page-break-inside: avoid; page-break-after: auto; }
            @page { margin: 1cm; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Pantech Kenya Limited</h1>
            <p>Official Product Catalog & Inventory List</p>
            <p style="font-size: 12px; margin-top: 5px;">Generated on <%= Time.current.strftime('%B %d, %Y') %> | total: <%= products.size %> Items</p>
        </header>

        <table>
            <thead>
                <tr>
                    <th class="num-cell">#</th>
                    <th class="img-cell">Image</th>
                    <th>Product Details</th>
                    <th>Category</th>
                    <th>Price (KES)</th>
                </tr>
            </thead>
            <tbody>
                <% products.each_with_index do |p, index| %>
                <tr>
                    <td class="num-cell"><%= index + 1 %></td>
                    <td class="img-cell">
                        <% if p['Media URLs'].present? %>
                            <img src="<%= p['Media URLs'].split(',').first.strip %>" class="product-img" loading="lazy">
                        <% else %>
                            <div class="product-img" style="display:flex;align-items:center;justify-content:center;color:#ccc;background:#eee;font-size:10px;">No Image</div>
                        <% end %>
                    </td>
                    <td>
                        <div style="font-weight: 600; font-size: 15px; margin-bottom: 5px;"><%= p['Title'] %></div>
                        <div class="desc"><%= p['Description'] %></div>
                        <a href="https://carboncube-ke.com/ads/<%= slugify(p['Title']) %>?id=<%= p['ID'] %>" target="_blank" class="view-link">View Online</a>
                    </td>
                    <td>
                        <div style="font-weight: 600;"><%= p['Category'] %></div>
                        <div style="color: var(--secondary);"><%= p['Subcategory'] %></div>
                    </td>
                    <td class="price">
                        <%= number_with_delimiter(p['Price']) %>
                    </td>
                </tr>
                <% end %>
            </tbody>
        </table>

        <div class="footer">
            <p>&copy; <%= Time.current.year %> Pantech Kenya Limited. All rights reserved.</p>
            <p>Confidential Business Document</p>
        </div>
    </div>
</body>
</html>
}

# Helpers
def number_with_delimiter(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def slugify(title)
  return "product" if title.blank?
  title.downcase
       .gsub(/[^a-z0-9\s]/, '')
       .gsub(/\s+/, '-')
       .strip
end

# Render ERB
renderer = ERB.new(template)
html_content = renderer.result(binding)

File.write(html_path, html_content)
puts "✓ Successfully generated HTML catalog at: #{html_path}"
