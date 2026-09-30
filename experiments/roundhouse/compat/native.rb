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
end

module ActionController
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
  class Base
    def self.sanitize_sql_like(value, escape_character = '\\')
      value.to_s.gsub(escape_character, escape_character * 2)
        .gsub('%', escape_character + '%').gsub('_', escape_character + '_')
    end
  end
end

class User
  def self.authenticate_by(email_address:, password:)
    return nil if password.nil? || password.empty?
    record = User.find_by(email_address: email_address.to_s.strip.downcase)
    unless record
      BCrypt::Password.create(password)
      return nil
    end
    record.authenticate(password) ? record : nil
  end

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

module NativeCalendar
  DAYNAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
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
  class HealthController < ActionController::Base
    def process_action(action_name)
      render('<!DOCTYPE html><html><body style="background-color:green"></body></html>')
    end
  end
end
