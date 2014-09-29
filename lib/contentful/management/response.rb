# -*- encoding: utf-8 -*-
require_relative 'error'
require 'multi_json'

module Contentful
  module Management
    # An object representing an answer by the contentful service. It is later used
    # to build a Resource, which is done by the ResourceBuilder.
    #
    # The Response parses the http response (as returned by the underlying http library) to
    # a JSON object. Responses can be asked the following methods:
    # - #raw (raw HTTP response by the HTTP library)
    # - #object (the parsed JSON object)
    # - #request (the request the response is refering to)
    #
    # It also sets a #status which can be one of:
    # - :ok (seems to be a valid resource object)
    # - :contentful_error (valid error object)
    # - :not_contentful (valid json, but missing the contentful's sys property)
    # - :unparsable_json (invalid json)
    #
    # Error Repsonses also contain a:
    # - :error_message
    class Response
      attr_reader :raw, :object, :status, :error_message, :request

      def initialize(raw, request = nil)
        @raw = raw
        @request = request
        @status = :ok

        if service_unavailable_response?
          @status = :service_unavailable
          @error_message = 'Service Unavailable, contenful.com API seems to be down'
        elsif no_content_response?
          @status = :no_content
          @object = true
        elsif parse_json!
          parse_contentful_error!
        end
      end

      private

      def service_unavailable_response?
        @raw.status == 503
      end

      def no_content_response?
        @raw.to_s == '' && @raw.status == 204
      end

      def parse_json!
        body = unzip_response(raw)
        @object = MultiJson.load(body)
        true
      rescue MultiJson::LoadError => error
        @status = :unparsable_json
        @error_message = error.message
        @object = error
        false
      end

      def parse_contentful_error!
        if contentful_object?
          invalid_object? ? contentful_object_error : false
        else
          not_contentful_object_error
        end
      end

      def invalid_object?
        @object['sys']['type'] == 'Error'
      end

      def contentful_object_error
        @status = :contentful_error
        @error_message = object['message']
        true
      end

      def not_contentful_object_error
        @status = :not_contentful
        @error_message = 'No contentful system properties found in object'
      end

      def contentful_object?
        @object && @object['sys']
      end

      def unzip_response(response)
        parsed_response = response.to_s
        if response.headers['Content-Encoding'].eql?('gzip') then
          sio = StringIO.new(parsed_response)
          gz = Zlib::GzipReader.new(sio)
          gz.read
        else
          parsed_response
        end
      end
    end
  end
end
