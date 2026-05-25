MissionControl::Jobs.base_controller_class = "::ApplicationController"
MissionControl::Jobs.http_basic_auth_enabled = false

module MissionControlJobsFullNavigation
  def navigation_sections
    { queues: [ "Queues", application_queues_path(@application) ] }.tap do |sections|
      supported_job_statuses.each do |status|
        sections[navigation_section_for_status(status)] = [
          "#{status.to_s.titleize} jobs (#{jobs_count_with_status(status)})",
          application_jobs_path(@application, status)
        ]
      end

      sections[:workers] = [ "Workers", application_workers_path(@application) ] if workers_exposed?
      sections[:recurring_tasks] = [ "Recurring tasks", application_recurring_tasks_path(@application) ] if recurring_tasks_supported?
    end
  end

  def navigation_section_for_status(status)
    return :pending_jobs if status.to_sym == :pending

    super
  end
end

ActiveSupport.on_load(:action_view) do
  MissionControl::Jobs::NavigationHelper.prepend(MissionControlJobsFullNavigation)
end
