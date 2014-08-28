class Support::Api::TicketCommentsController < SupportBaseController

  load_and_authorize_resource :class => "Ticket"
  skip_before_action :verify_authenticity_token

  def create
    issue_reference = params[:ticket_id]
    response = current_user.organization.tickets.create_comment(issue_reference, params[:text], current_user.email)
    respond_to do |format|
      format.json {
        render :json => response
      }
    end
  end

  def destroy
    issue_reference = params[:ticket_id]
    comment_id = params[:id]
    response = current_user.organization.tickets.destroy_comment(issue_reference, comment_id)
    respond_to do |format|
      format.json {
        render :json => response
      }
    end
  end

end