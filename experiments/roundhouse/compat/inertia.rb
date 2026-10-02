module NativeInertia
  # Evaluate Inertia's lazy props before encoding the page's JSON tree.
  def self.resolve(value)
    if value.is_a?(Date)
      value.iso8601
    elsif value.is_a?(Time)
      value.iso8601(3)
    elsif value.is_a?(BigDecimal)
      value.to_s('F')
    elsif value.is_a?(Proc)
      resolve(value.call)
    elsif value.is_a?(Hash)
      resolved = {}
      value.each { |key, item| resolved[key.to_s] = resolve(item) }
      resolved
    elsif value.is_a?(Array)
      value.map { |item| resolve(item) }
    else
      value
    end
  end
end

module ActionController
  class Base
    attr_accessor :native_inertia_component

    def render(body = '', inertia: nil, status: :ok, content_type: nil, location: nil)
      if inertia
        shared = {
          auth: {
            authenticated: !::Current.session.nil?,
            email: ::Current.user && ::Current.user.email_address,
            role: ::Current.user && ::Current.user.role,
            admin: ::Current.user && ::Current.user.admin? || false,
            onboarding_required: onboarding_required?
          },
          flash: { notice: flash[:notice], alert: flash[:alert] },
          errors: {},
          paths: {
            root: '/', transactions: '/transactions', imports: '/imports',
            spending: '/spending', budgets: '/budgets', subcategories: '/subcategories',
            insights: '/insights', offline: '/offline', ai_preferences: '/ai_preferences',
            settings: '/settings', onboarding: '/onboarding', admin: '/admin',
            ai_controls: '/admin/ai_controls', models: '/admin/models', jobs: '/admin/jobs',
            session: '/session', new_session: '/session/new', passwords: '/passwords',
            new_registration: '/registrations/new'
          }
        }
        payload = JSON.generate({
          component: native_inertia_component, props: NativeInertia.resolve(shared.merge(inertia)),
          url: request.fullpath, version: NativeInertia::VERSION,
          encryptHistory: true, clearHistory: false
        })
        @headers['Vary'] = 'X-Inertia'
        token = ActionView::ViewHelpers.form_authenticity_token
        # The native unsigned jar accepts the cookie value directly.
        # An options Hash is serialized verbatim and cannot be used as a token.
        cookies['XSRF-TOKEN'] = token
        if request.env['HTTP_X_INERTIA'].to_s == 'true'
          body = payload
          content_type = 'application/json'
          @headers['X-Inertia'] = 'true'
        else
          body = '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
                 '<meta name="csrf-token" content="' + token + '"><title>Transactions</title>' + NativeInertia::ASSET_TAGS +
                 '</head><body><div id="app"></div><script data-page="app" type="application/json">' +
                 payload.gsub('<', '\\u003c').gsub('>', '\\u003e').gsub('&', '\\u0026') + '</script></body></html>'
        end
      end
      @body = body
      @status = resolve_status(status)
      @performed = true
      @content_type = content_type unless content_type.nil?
      @location = location unless location.nil?
      nil
    end
  end
end
