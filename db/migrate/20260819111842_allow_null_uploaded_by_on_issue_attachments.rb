class AllowNullUploadedByOnIssueAttachments < ActiveRecord::Migration[7.1]
  def change
    # Anonymous (not logged-in) reporters can now attach screenshots when
    # filing a public issue, so there may be no uploader to record.
    change_column_null :issue_attachments, :uploaded_by_type, true
    change_column_null :issue_attachments, :uploaded_by_id, true
  end
end
