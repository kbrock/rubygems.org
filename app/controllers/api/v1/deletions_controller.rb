class Api::V1::DeletionsController < Api::BaseController
  include TagHelper
  include JavaScriptHelper
  skip_before_action :verify_authenticity_token, only: [:create, :destroy]

  before_action :authenticate_with_api_key, only: [:create, :destroy]
  before_action :verify_authenticated_user, only: [:create, :destroy]
  before_action :find_rubygem_by_name,      only: [:create, :destroy]
  before_action :validate_gem_and_version,  only: [:create]

  def create
    @deletion = current_user.deletions.build(version: @version)
    if @deletion.save
      StatsD.increment 'yank.success'
      render text: "Successfully deleted gem: #{escape_once @version.to_title}"
    else
      StatsD.increment 'yank.failure'
      render text: "The version #{escape_once params[:version]} has already been deleted.",
             status: :unprocessable_entity
    end
  end

  def destroy
    render text: "Unyanking of gems is no longer supported.",
           status: :gone
  end

  private

  def validate_gem_and_version
    if !@rubygem.hosted?
      render text: "This gem does not exist.",
             status: :not_found
    elsif !@rubygem.owned_by?(current_user)
      render text: "You do not have permission to delete this gem.",
             status: :forbidden
    else
      begin
        slug = if params[:platform].blank?
                 j(params[:version])
               else
                 "#{j params[:version]}-#{j params[:platform]}"
               end
        @version = Version.find_from_slug!(@rubygem, slug)
      rescue ActiveRecord::RecordNotFound
        render text: "The version #{escape_once params[:version]} does not exist.",
               status: :not_found
      end
    end
  end
end
