seller = Seller.find_by(email: 'victorquaint@gmail.com')
puts 'Testing email with simplified markdown...'
mail = SellerCommunicationsMailer.with(
  user: seller,
  user_type: 'seller',
  subject: 'Test: Uniform Template with Markdown',
  message: '**Hello Victor!**

This is a test of the *uniform email template* with **markdown support**.

## Features:
- Professional design
- Basic markdown formatting
- Consistent branding

### Lists:
1. Numbered items
2. More items

- Bullet points
- More bullets

> This is a blockquote

`Inline code` and **bold text**.

Best regards,
Carbon Cube Kenya Team'
).custom_communication
mail.deliver_now
puts 'Email sent successfully!'
