require_relative "app/controllers/development/previews_controller"
# SQLite-backed native Active Job adapter. Persist arguments and failures,
# return a real job identifier, and resume interrupted work on restart.
class NativeJobHandle
  attr_reader :job_id
  def initialize(job_id)
    @job_id = job_id
  end
end

module NativeJobs
  def self.setup
    SqliteAdapter.execute_ddl("CREATE TABLE IF NOT EXISTS native_jobs (id TEXT PRIMARY KEY, name TEXT NOT NULL, arguments TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'queued', error TEXT, created_at TEXT NOT NULL, finished_at TEXT)")
    SqliteAdapter.execute_ddl("UPDATE native_jobs SET status = 'queued' WHERE status = 'running'")
  end

  def self.enqueue(name, arguments)
    id = SecureRandom.uuid
    sql = "INSERT INTO native_jobs (id, name, arguments, status, created_at) VALUES (" +
      [id, name, JSON.generate(NativeInertia.resolve(arguments)), 'queued', Time.now.utc.iso8601].map { |value| Db.escape_string(value) }.join(', ') + ")"
    SqliteAdapter.execute_ddl(sql)
    NativeJobHandle.new(id)
  end

  def self.pending_count
    rows = ActiveRecord.adapter.select_rows("SELECT COUNT(*) AS n FROM native_jobs WHERE status = 'queued'")
    rows[0]['n'].to_i
  end

  def self.drain
    rows = ActiveRecord.adapter.select_rows("SELECT * FROM native_jobs WHERE status = 'queued' ORDER BY created_at, id LIMIT 1")
    return 0 if rows.empty?
    row = rows[0]
    id = Db.escape_string(row['id'].to_s)
    SqliteAdapter.execute_ddl("UPDATE native_jobs SET status = 'running' WHERE id = " + id + " AND status = 'queued'")
    begin
      perform(row['name'].to_s, JSON.parse(row['arguments'].to_s))
      SqliteAdapter.execute_ddl("UPDATE native_jobs SET status = 'completed', error = NULL, finished_at = " + Db.escape_string(Time.now.utc.iso8601) + " WHERE id = " + id)
    rescue StandardError, ScriptError => error
      SqliteAdapter.execute_ddl("UPDATE native_jobs SET status = 'failed', error = " + Db.escape_string(error.class.to_s + ': ' + error.message) + ", finished_at = " + Db.escape_string(Time.now.utc.iso8601) + " WHERE id = " + id)
      warn '[job] ' + row['name'].to_s + ': ' + error.message
      warn error.backtrace.join("\n")
    ensure
      Current.reset
      # The scheduler thread persists across jobs. Its diagnostic broadcast
      # log must have the same per-operation lifetime as an HTTP request's.
      Broadcasts.reset_log!
    end
    1
  end

  def self.perform(name, args)
    case name
    when 'ClassifyImportRowsJob'
      ClassifyImportRowsJob.perform_now(args[0].to_i, args[1])
    when 'ClassifyTransactionsJob'
      ClassifyTransactionsJob.perform_now(args[0].to_i, args[1], args[2])
    when 'GenerateInsightsJob'
      GenerateInsightsJob.perform_now(Date.iso8601(args[0].to_s), Date.iso8601(args[1].to_s), args[2])
    when 'ProcessAiChatMessageJob'
      ProcessAiChatMessageJob.perform_now(args[0].to_i, args[1].to_i)
    when 'CsvUploadReminderJob'
      CsvUploadReminderJob.perform_now(args[0])
    when 'RefreshRubyLlmModelsJob'
      RefreshRubyLlmModelsJob.perform_now
    else
      raise ArgumentError, 'Unknown native job: ' + name
    end
    nil
  end

  def self.rows
    ActiveRecord.adapter.select_rows('SELECT * FROM native_jobs ORDER BY created_at DESC, id DESC LIMIT 100')
  end
end

module ActiveJob
  def self.pending_count
    NativeJobs.pending_count
  end
  def self.drain
    NativeJobs.drain
  end
end

class NativeJobsController < ApplicationController
  def process_action(action_name)
    resume_session
    require_authentication
    return if performed?
    require_admin_user
    return if performed?
    if action_name == :retry
      id = Db.escape_string(@params['id'].to_s)
      SqliteAdapter.execute_ddl("UPDATE native_jobs SET status = 'queued', error = NULL, finished_at = NULL WHERE status = 'failed' AND id = " + id)
      redirect_to('/admin/jobs')
    elsif action_name == :destroy
      id = Db.escape_string(@params['id'].to_s)
      SqliteAdapter.execute_ddl("DELETE FROM native_jobs WHERE status != 'running' AND id = " + id)
      redirect_to('/admin/jobs')
    else
      token = ActionView::ViewHelpers.form_authenticity_token
      rows = NativeJobs.rows.map do |row|
        id = row['id'].to_s
        actions = ''
        if row['status'] == 'failed'
          actions += '<form method="post" action="/admin/jobs/' + id + '/retry"><input type="hidden" name="authenticity_token" value="' + token + '"><button>Retry</button></form>'
        end
        if row['status'] != 'running'
          actions += '<form method="post" action="/admin/jobs/' + id + '/destroy"><input type="hidden" name="authenticity_token" value="' + token + '"><button>Delete</button></form>'
        end
        '<tr>' + [row['name'], row['status'], row['created_at'], row['finished_at'], row['error']].map { |value| '<td>' + escape(value.to_s) + '</td>' }.join + '<td>' + actions + '</td></tr>'
      end.join
      render('<!DOCTYPE html><html><head><meta charset="utf-8"><title>Background jobs</title><style>body{font:14px system-ui;max-width:1200px;margin:32px auto;color:#18181b}table{border-collapse:collapse;width:100%}td,th{text-align:left;padding:10px;border-bottom:1px solid #ddd}form{display:inline-block;margin-right:8px}</style></head><body><a href="/admin">Back to admin</a><h1>Background jobs</h1><p>Queued, running, completed and failed work. Interrupted work resumes when the app restarts.</p><table><thead><tr><th>Job</th><th>Status</th><th>Queued</th><th>Finished</th><th>Error</th><th>Actions</th></tr></thead><tbody>' + rows + '</tbody></table></body></html>', content_type: 'text/html')
    end
    nil
  end

  def escape(value)
    value.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
  end
end

module NativeRoutes
  def self.table
    [
      ActionDispatch::Router::Route.new('GET', '/admin/jobs', :native_jobs, :index),
      ActionDispatch::Router::Route.new('POST', '/admin/jobs/:id/retry', :native_jobs, :retry),
      ActionDispatch::Router::Route.new('POST', '/admin/jobs/:id/destroy', :native_jobs, :destroy),
      ActionDispatch::Router::Route.new('GET', '/admin/first_time_flow_preview', :native_preview, :first_time_flow)
    ]
  end
end


module Development
  class PreviewsController
    def process_action(action_name)
      resume_session
      require_authentication
      return if performed?
      require_admin_user
      return if performed?
      first_time_flow
    end
  end
end
