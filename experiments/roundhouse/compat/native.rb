# Supplemental framework methods omitted by Roundhouse's Spinel runtime.
# This file is loaded only in the generated native project.
module Sock
  ffi_func :sp_net_listen_host, [:str, :int, :int], :int

  def self.sphttp_listen(port, reuse)
    Sock.sp_net_listen_host('127.0.0.1', port, 1024)
  end
end

module InertiaRails
  def self.defer(group: nil)
    yield
  end
end

class NativePagination
  attr_reader :count, :page, :pages, :from, :to, :offset

  def initialize(count, page, limit)
    @count = count
    @pages = [1, (count.to_f / limit).ceil].max
    @page = page.clamp(1, @pages)
    @offset = (@page - 1) * limit
    @from = count == 0 ? 0 : @offset + 1
    @to = [@offset + limit, count].min
  end
end

module NativeViewHelpers
  def self.number_with_delimiter(value)
    value.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
  end

  def self.number_to_currency(value, precision: 2)
    number = value.to_f
    prefix = number < 0 ? '-$' : '$'
    digits = format("%.*f", precision, number.abs)
    pieces = digits.split('.')
    fraction = precision == 0 ? '' : '.' + pieces[1].to_s
    prefix + number_with_delimiter(pieces[0]) + fraction
  end

  def self.pluralize(count, singular, plural = nil)
    label = count == 1 ? singular : (plural || singular + 's')
    "#{count} #{label}"
  end

  def self.time_ago_in_words(time)
    ActionView::ViewHelpers.time_ago_in_words(time)
  end
end

module ActionController
  module JsonRender
    def self.encode(value)
      JSON.generate(NativeInertia.resolve(value))
    end
  end

  class Base
    def helpers
      NativeViewHelpers
    end

    def pagy(method, relation, limit:)
      raise ArgumentError, 'Only offset pagination is supported' unless method == :offset
      pagination = NativePagination.new(relation.count, @params['page'].to_s.to_i, limit)
      [pagination, relation.offset(pagination.offset).limit(limit).to_a]
    end
  end
end

module ApplicationHelper
  def self.number_to_currency(value)
    NativeViewHelpers.number_to_currency(value)
  end
end

class OfflineSnapshot
  def number_to_currency(value)
    NativeViewHelpers.number_to_currency(value)
  end
end

module ActiveRecord
  class Connection
    def data_source_exists?(name)
      ActiveRecord.adapter.select_rows("SELECT name FROM sqlite_master WHERE type IN ('table', 'view') AND name = #{Db.escape_string(name)}").any?
    end
  end

end

module Params
  # Inertia sends JSON scalars, while generated params DTOs store text.
  # Keep scalar values provided and convert them at that typed boundary.
  def self.str(sub, key, fallback)
    value = sub.fetch(key, nil)
    return fallback if value.nil? || value.is_a?(Hash) || value.is_a?(Array)
    value.to_s
  end

  def self.provided(sub, key)
    return false unless sub.key?(key)
    value = sub[key]
    !value.nil? && !value.is_a?(Hash) && !value.is_a?(Array)
  end
end

class Model
  def price(kind)
    RubyLLM::Model.new(pricing: pricing || {}).price(kind)
  end
end

class RubyLlmModelImporter
  def self.save_models!
    RubyLLM.models.map do |model|
      record = Model.find_by(model_id: model.id, provider: model.provider) || Model.new
      record.update!(model_id: model.id, provider: model.provider, name: model.name,
        family: model.family, model_created_at: model.created_at,
        context_window: model.context_window, max_output_tokens: model.max_output_tokens,
        knowledge_cutoff: model.knowledge_cutoff, modalities: model.modalities,
        capabilities: model.capabilities, pricing: model.pricing, metadata: model.metadata)
    end
  end
end

class User
  # Tokens in this isolated native database carry both the user id and
  # password salt, expire after 15 minutes, and become invalid on reset.
  def password_reset_token
    expires = ActionController::MessageVerifier.iso8601_ms(Time.now + 900)
    payload = JSON.generate([id, password_digest.to_s[0, 29]])
    ActionController::MessageVerifier.data_envelope(
      Rails.application.secret_key_base, 'transactions/password_reset', payload,
      'password_reset', '"' + expires + '"', false
    )
  end

  def self.find_by_password_reset_token!(token)
    json = ActionController::MessageVerifier.verified_data_json(
      Rails.application.secret_key_base, 'transactions/password_reset', token,
      'password_reset', false
    )
    raise ActiveSupport::MessageVerifier::InvalidSignature if json.empty?
    values = JSON.parse(json)
    record = User.find_by(id: values[0].to_i)
    unless record && ActionController::MessageVerifier.secure_compare(record.password_digest.to_s[0, 29], values[1].to_s)
      raise ActiveSupport::MessageVerifier::InvalidSignature
    end
    record
  end
end

module RouteHelpers
  def self.admin_first_time_flow_preview_path
    '/admin/first_time_flow_preview'
  end
end

module ActionCable
  # The scaffold encoder only handles integer-valued payloads. App channel
  # messages contain strings and nested objects, so encode the full JSON tree.
  def self.payload_json(payload)
    JSON.generate(NativeInertia.resolve(payload))
  end
end

class AiChatChannel
  def self.broadcast_to(record, message)
    ActionCable.server.broadcast(AiChatChannel.broadcasting_for(record), message)
  end
end

class ImportBatchChannel
  def self.broadcast_to(record, message)
    ActionCable.server.broadcast(ImportBatchChannel.broadcasting_for(record), message)
  end
end

module Rails
  class PwaController < ActionController::Base
    def process_action(action_name)
      if action_name == :manifest
        render(Views::Pwa.manifest_json, content_type: 'application/manifest+json')
      elsif action_name == :service_worker
        render(File.read('public/service-worker.js'), content_type: 'text/javascript')
      end
    end
  end

  class HealthController < ActionController::Base
    def process_action(action_name)
      render('<!DOCTYPE html><html><body style="background-color:green"></body></html>')
    end
  end
end

module ActionDispatch
  class Session
    # The shared runtime's string-only cookie codec loses booleans and
    # integers. Keep the native app's session metadata typed and signed.
    def to_cookie
      ActionController::MessageVerifier.data_envelope(
        Rails.application.secret_key_base, 'transactions/session', JSON.generate(to_h),
        'session', 'null', false
      )
    end
    def self.from_cookie(raw)
      return Session.new if raw.nil? || raw.empty?
      json = ActionController::MessageVerifier.verified_data_json(
        Rails.application.secret_key_base, 'transactions/session', raw, 'session', false
      )
      return Session.new if json.empty?
      data = JSON.parse(json)
      data.is_a?(Hash) ? Session.new(data) : Session.new
    rescue JSON::ParserError
      Session.new
    end
  end
end
