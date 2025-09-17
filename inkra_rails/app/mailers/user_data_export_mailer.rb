class UserDataExportMailer < ApplicationMailer
  default from: 'Inkra <noreply@inkra.app>'

  def export_ready(user, email, download_url)
    @user = user
    @download_url = download_url
    @expires_at = 7.days.from_now.strftime('%B %d, %Y')
    
    mail(
      to: email,
      subject: 'Your Inkra Data Export is Ready'
    )
  end

  def export_failed(user, email, error_message)
    @user = user
    @error_message = error_message
    
    mail(
      to: email,
      subject: 'Inkra Data Export Failed'
    )
  end

  def account_deleted(email, feedback_data = {})
    @user_email = email
    @feedback_data = feedback_data
    @deletion_date = Time.current.strftime('%B %d, %Y at %I:%M %p %Z')
    
    mail(
      to: email,
      subject: 'Your Inkra Account Has Been Deleted'
    )
  end

  def deletion_failed(email, error_message)
    @user_email = email
    @error_message = error_message
    
    mail(
      to: email,
      subject: 'Inkra Account Deletion Failed'
    )
  end
end