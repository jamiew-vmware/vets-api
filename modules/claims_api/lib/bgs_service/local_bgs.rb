# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

require 'claims_api/claim_logger'

module ClaimsApi
  class LocalBGS
    attr_accessor :external_uid, :external_key

    def initialize(external_uid:, external_key:)
      @application = Settings.bgs.application
      @client_ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
      @client_station_id = Settings.bgs.client_station_id
      @client_username = Settings.bgs.client_username
      @env = Settings.bgs.env
      @mock_response_location = Settings.bgs.mock_response_location
      @mock_responses = Settings.bgs.mock_responses
      @external_uid = external_uid || Settings.bgs.external_uid
      @external_key = external_key || Settings.bgs.external_key
      @forward_proxy_url = Settings.bgs.url
      @ssl_verify_mode = Settings.bgs.ssl_verify_mode == 'none' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      @timeout = Settings.bgs.timeout || 120
    end

    def header # rubocop:disable Metrics/MethodLength
      # Stock XML structure {{{
      header = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <env:Header>
          <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
            <wsse:UsernameToken>
              <wsse:Username></wsse:Username>
            </wsse:UsernameToken>
            <vaws:VaServiceHeaders xmlns:vaws="http://vbawebservices.vba.va.gov/vawss">
              <vaws:CLIENT_MACHINE></vaws:CLIENT_MACHINE>
              <vaws:STN_ID></vaws:STN_ID>
              <vaws:applicationName></vaws:applicationName>
              <vaws:ExternalUid ></vaws:ExternalUid>
              <vaws:ExternalKey></vaws:ExternalKey>
            </vaws:VaServiceHeaders>
          </wsse:Security>
        </env:Header>
      EOXML

      { Username: @client_username, CLIENT_MACHINE: @client_ip,
        STN_ID: @client_station_id, applicationName: @application,
        ExternalUid: @external_uid, ExternalKey: @external_key }.each do |k, v|
        header.xpath(".//*[local-name()='#{k}']")[0].content = v
      end
      header.to_s
    end

    def full_body(action:, body:, namespace:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <?xml version="1.0" encoding="UTF-8"?>
          <env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:tns="#{namespace}" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
          #{header}
          <env:Body>
            <tns:#{action}>
              #{body}
            </tns:#{action}>
          </env:Body>
          </env:Envelope>
      EOXML
      body.to_s
    end

    def parsed_response(res, action, key)
      parsed = Hash.from_xml(res.body)
      parsed.dig('Envelope', 'Body', "#{action}Response", key)
            &.deep_transform_keys(&:underscore)
            &.deep_symbolize_keys || {}
    end

    def make_request(endpoint:, action:, body:, key:) # rubocop:disable Metrics/MethodLength
      connection = log_duration event: 'establish_ssl_connection' do
        Faraday::Connection.new(ssl: { verify_mode: @ssl_verify_mode })
      end
      connection.options.timeout = @timeout

      wsdl = log_duration event: 'connection_wsdl_get', endpoint: endpoint do
        connection.get("#{Settings.bgs.url}/#{endpoint}?WSDL")
      end
      target_namespace = Hash.from_xml(wsdl.body).dig('definitions', 'targetNamespace')
      response = log_duration event: 'connection_post', endpoint: endpoint, action: action do
        connection.post("#{Settings.bgs.url}/#{endpoint}", full_body(action: action,
                                                                     body: body,
                                                                     namespace: target_namespace),
                        {
                          'Content-Type' => 'text/xml;charset=UTF-8',
                          'Host' => "#{@env}.vba.va.gov",
                          'Soapaction' => "\"#{action}\""
                        })
      end
      log_duration event: 'parsed_response', key: key do
        parsed_response(response, action, key)
      end
    end

    def find_poa_by_participant_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId />
      EOXML

      { ptcpntId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'ClaimantServiceBean/ClaimantWebService', action: 'findPOAByPtcpntId', body: body,
                   key: 'return')
    end

    def find_by_ssn(ssn)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ssn />
      EOXML

      { ssn: ssn }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'PersonWebServiceBean/PersonWebService', action: 'findPersonBySSN', body: body,
                   key: 'PersonDTO')
    end

    private

    def log_duration(event: 'default', **extra_params)
      # Who are we to question sidekiq's use of CLOCK_MONOTONIC to avoid negative durations?
      # https://github.com/sidekiq/sidekiq/issues/3999
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      result = yield
      duration = (::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time).round(4)

      # event should be first key in log, duration last
      ClaimsApi::Logger.log 'local_bgs', { event: event }.merge(extra_params).merge({ duration: duration })
      StatsD.measure("api.claims_api.local_bgs.#{event}.duration", duration, tags: {})
      result
    end
  end
end
