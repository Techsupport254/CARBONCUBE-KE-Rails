class SeedHelpCenterFaqs < ActiveRecord::Migration[7.1]
  FAQS = [
    {
      category: "account",
      position: 1,
      question: "I can't log in to my account. What should I do?",
      answer: "1. Confirm you are using the same email or phone number you registered with.\n2. Double-check your password for typos - passwords are case-sensitive.\n3. If you still can't log in, use 'Forgot Password' on the sign-in page to reset it.\n4. Check your email (including spam/junk) for the reset link and follow it before it expires.\n5. If you signed up with Google, use the 'Continue with Google' button instead of a password.\n6. Still locked out? Report the issue at /issues/new or email info@carboncube-ke.com."
    },
    {
      category: "account",
      position: 2,
      question: "I didn't receive my verification or password reset email.",
      answer: "1. Check your spam, junk, and promotions folders - automated emails often land there.\n2. Confirm you entered the correct email address with no typos.\n3. Wait 5-10 minutes; email delivery can occasionally be delayed.\n4. Try resending the email from the login or verification page.\n5. If it still doesn't arrive, contact info@carboncube-ke.com so we can verify your account manually."
    },
    {
      category: "account",
      position: 3,
      question: "How do I update my profile or contact details?",
      answer: "1. Sign in and open your account dashboard.\n2. Go to Profile or Settings.\n3. Edit your name, phone number, or location and save.\n4. Keep your phone number current - it is how buyers and sellers reach each other on the marketplace."
    },
    {
      category: "buying",
      position: 1,
      question: "How do I buy something on Carbon Cube Kenya?",
      answer: "1. Browse or search for the item and open the ad.\n2. Review the ad details and the seller's shop information and ratings.\n3. Click 'Contact Seller' to reveal the seller's contact details.\n4. Reach out to the seller directly to negotiate the price and agree on payment, delivery, or pickup.\n5. Carbon Cube Kenya connects you with sellers - the purchase, payment, and delivery are agreed directly between you and the seller."
    },
    {
      category: "buying",
      position: 2,
      question: "How does delivery work?",
      answer: "1. Carbon Cube Kenya is a marketplace - we do not handle delivery or logistics.\n2. Agree on delivery or pickup directly with the seller when you contact them.\n3. Many sellers offer delivery within their area or can arrange a courier - ask about cost and timing before paying.\n4. For pickup, choose a safe public location and inspect the item before handing over payment."
    },
    {
      category: "buying",
      position: 3,
      question: "What does adding an item to my cart do?",
      answer: "1. Your cart is a shortlist - it saves ads you are interested in so you can compare them in one place.\n2. Adding to cart does not place an order or reserve the item.\n3. To buy, open the ad and use 'Contact Seller' to reach the seller directly."
    },
    {
      category: "buying",
      position: 4,
      question: "Is it safe to pay a seller directly?",
      answer: "1. Inspect the item in person before paying whenever possible.\n2. Meet in a safe, public place for pickups and exchanges.\n3. Avoid sending advance payments to sellers you haven't verified - check their ratings, reviews, and shop history first.\n4. If you pay via M-Pesa, keep the confirmation SMS as your proof of payment.\n5. If a deal feels suspicious, walk away and report the ad to us at /issues/new."
    },
    {
      category: "buying",
      position: 5,
      question: "A seller didn't deliver, or I received the wrong or damaged item.",
      answer: "1. Contact the seller first - most issues are resolved directly between buyer and seller.\n2. Keep your evidence: M-Pesa confirmation, messages, and photos of the item.\n3. If the seller is unresponsive or won't resolve it, open a case on our Dispute Resolution page - initial mediation through the platform is free.\n4. Report the incident at /issues/new so our team can review the seller. Report suspected fraud or counterfeits immediately."
    },
    {
      category: "payments",
      position: 1,
      question: "My M-Pesa payment for a seller plan didn't go through, or I never got the STK push.",
      answer: "1. Confirm the phone number entered is your active M-Pesa line and the phone is on.\n2. Check for a pending STK prompt - open your M-Pesa app or dial *334# if the push didn't appear.\n3. Make sure you have enough M-Pesa balance to cover the plan plus transaction fees.\n4. Retry promptly - STK push requests expire after about 10 minutes.\n5. If money was deducted but your plan wasn't activated, send your M-Pesa confirmation code to info@carboncube-ke.com or report it at /issues/new."
    },
    {
      category: "payments",
      position: 2,
      question: "I paid for a tier plan but my account hasn't upgraded.",
      answer: "1. Wait 5-10 minutes - payment confirmation can take a short while to sync.\n2. Check for an M-Pesa confirmation SMS with a transaction code.\n3. Refresh your seller dashboard or log out and back in.\n4. If the plan still hasn't activated after 30 minutes, contact info@carboncube-ke.com with your M-Pesa transaction code, or report it at /issues/new."
    },
    {
      category: "selling",
      position: 1,
      question: "My seller account is still pending approval.",
      answer: "1. Make sure you submitted all required verification documents during registration.\n2. Check your email (including spam) for any requests for additional information.\n3. Reviews typically complete within a few business days.\n4. If it has been longer, visit the Vendor Help page or contact info@carboncube-ke.com."
    },
    {
      category: "selling",
      position: 2,
      question: "Why was my ad rejected or taken down?",
      answer: "1. Check the rejection notice in your seller dashboard or email for the stated reason.\n2. Common causes: low-quality images, missing specifications, prohibited items, or misleading pricing.\n3. Fix the highlighted issue and resubmit the ad.\n4. If you believe it was removed in error, report it at /issues/new with the ad title or ID."
    },
    {
      category: "selling",
      position: 3,
      question: "As a seller, how do I handle delivery and customer inquiries?",
      answer: "1. Sellers on Carbon Cube Kenya handle their own logistics - the platform connects you with buyers but does not deliver.\n2. Agree on delivery, courier, or pickup details directly with each buyer.\n3. Respond to buyer contacts promptly - fast replies lead to more sales.\n4. Keep your contact details and shop information up to date in your seller dashboard."
    },
    {
      category: "technical",
      position: 1,
      question: "The site or app is slow, or pages won't load.",
      answer: "1. Refresh the page or restart the app.\n2. Check your internet connection - try switching between Wi-Fi and mobile data.\n3. Clear your browser cache and cookies, or try an incognito/private window.\n4. Try a different browser or device to isolate the problem.\n5. Check the status banner on the Report an Issue page - a known outage may be in progress.\n6. If it persists, report it at /issues/new with the page URL and a screenshot."
    },
    {
      category: "technical",
      position: 2,
      question: "The 'Contact Seller' button or seller contact details aren't showing.",
      answer: "1. Make sure you are signed in to your buyer account - seller contact details require a signed-in account.\n2. Refresh the ad page and try again.\n3. Check your internet connection and try a different browser or the app.\n4. If it still fails, report it at /issues/new with the ad title or link."
    },
    {
      category: "technical",
      position: 3,
      question: "How do I report a bug, security concern, or a suspicious ad?",
      answer: "1. Go to the Report an Issue page at /issues/new.\n2. Choose the matching category (Bug, Security, Design, etc.) and describe what happened.\n3. Attach a screenshot if you can - it speeds up diagnosis.\n4. Submit and track progress on the Issues page. You will get a confirmation email and updates as it is reviewed."
    },
    {
      category: "general",
      position: 1,
      question: "How do I contact customer support?",
      answer: "1. For platform problems, use Report an Issue at /issues/new - it is tracked and you get status updates.\n2. For general questions, use the Contact Us page, email info@carboncube-ke.com, or call +254 712 990 524.\n3. For questions about a specific item, contact the seller directly from the ad page first - it is usually the fastest route."
    },
    {
      category: "general",
      position: 2,
      question: "Is my personal data safe?",
      answer: "1. All traffic is encrypted over HTTPS and we never store your M-Pesa PIN or full payment credentials.\n2. Sellers go through a verification process before listing.\n3. You can review what we collect on the Privacy Policy page, and request deletion via the Data Deletion page.\n4. If you suspect unauthorized account activity, reset your password immediately and report it at /issues/new."
    }
  ].freeze

  def up
    FAQS.each do |attrs|
      Faq.find_or_create_by!(question: attrs[:question]) do |faq|
        faq.category = attrs[:category]
        faq.position = attrs[:position]
        faq.answer = attrs[:answer]
      end
    end
  end

  def down
    Faq.where(question: FAQS.map { |f| f[:question] }).delete_all
  end
end
