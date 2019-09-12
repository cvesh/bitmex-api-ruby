module Bitmex
  # Account Operations
  #
  # All read-only operations to load user's data are implemented and work as described in docs.
  # Multiple PUT/POST endpoints return 'Access Denied' and are not implemented. It seems that they are meant to be used internally by BitMEX only.
  #
  # @author Iulian Costan
  class User
    attr_reader :rest, :websocket

    # @param rest [Bitmex::Rest] the HTTP client
    # @param websocket [Bitmex::Websocket] the Websocket client
    def initialize(rest, websocket)
      @rest = rest
      @websocket = websocket
    end

    # Get your current affiliate/referral status.
    # @return [Hash] the affiliate status
    def affiliate_status
      get 'affiliateStatus'
    end

    # Check if a referral code is valid. If the code is valid, responds with the referral code's discount (e.g. 0.1 for 10%) and false otherwise
    # @param code [String] the referral code
    # @return [Decimal, nil] the discount or nil
    def check_referral_code(code)
      get 'checkReferralCode', referralCode: code do |response|
        return nil if !response.success? && [404, 451].include?(response.code)

        response.to_f
      end
    end

    # Get your account's commission status
    # @return [Hash] the commission by each product
    def commission
      get 'commission'
    end

    # Get a deposit address
    # @param currency [String] currency symbol
    # @return [String] the address
    def deposit_address(currency = 'XBt')
      get 'depositAddress', currency: currency do |response|
        raise response.body unless response.success?

        response.to_s
      end
    end

    # Get the execution history by day
    # @param symbol [String] the symbol to get the history for
    # @param timestamp [Datetime] the datetime to filter the history for
    # @return [Array] the history
    def execution_history(symbol = 'XBTUSD', timestamp = Date.today)
      get 'executionHistory', symbol: symbol, timestamp: timestamp
    end

    # Get your account's margin status
    # @param currency [String] the currency to filter by
    # @return [Hash] the margin
    def margin(currency = 'XBt')
      get 'margin', currency: currency
    end

    # Get the minimum withdrawal fee for a currency
    # This is changed based on network conditions to ensure timely withdrawals. During network congestion, this may be high. The fee is returned in the same currency.
    # @param currency [String] the currency to get the fee for
    # @return [Hash] the fee
    def min_withdrawal_fee(currency = 'XBt')
      get 'minWithdrawalFee', currency: currency
    end

    # Get your current wallet information
    # @return [Hash] the current wallet
    def wallet
      get 'wallet'
    end

    # Get a history of all of your wallet transactions (deposits, withdrawals, PNL)
    # @return [Array] the wallet history
    def wallet_history
      get 'walletHistory'
    end

    # Get a summary of all of your wallet transactions (deposits, withdrawals, PNL)
    # @return [Array] the wallet summary
    def wallet_summary
      get 'walletSummary'
    end

    # Get your user events
    # @param count [Integer] number of results to fetch
    # @param startId [Double] cursor for pagination
    # @return [Array] the events
    def events(count: 150, startId: nil)
      data = get '', resource: 'userEvent', count: count, startId: startId
      data.userEvents
    end

    # Get your alias on the leaderboard
    # @return [String] the alias on the leaderboard
    def nickname
      data = get 'name', resource: 'leaderboard'
      data.name
    end

    # Get all raw executions for your account
    # @!macro bitmex.filters
    #   @param filters [Hash] the filters to apply to mostly REST API requests with a few exceptions
    #   @option filters [String] :symbol the instrument symbol, this filter works in both REST and Websocket APIs
    #   @option filters [String] :filter generic table filter, send key/value pairs {https://www.bitmex.com/app/restAPI#Timestamp-Filters Timestamp Filters}
    #   @option filters [String] :columns array of column names to fetch; if omitted, will return all columns.
    #   @option filters [Double] :count (100) number of results to fetch.
    #   @option filters [Double] :start Starting point for results.
    #   @option filters [Boolean] :reverse (false) if true, will sort results newest first.
    #   @option filters [Datetime, String] :startTime Starting date filter for results.
    #   @option filters [Datetime, String] :endTime Ending date filter for results
    # @return [Array] the raw transactions
    # @yield [Hash] the execution
    def executions(filters = {}, &ablock)
      if block_given?
        websocket.listen execution: filters[:symbol], &ablock
      else
        get '', filters.merge(resource: :execution)
      end
    end

    private

    def method_missing(name, *_args, &_ablock)
      @data = get '' if @data.nil?
      @data.send name
    end

    def put(action, params, &ablock)
      path = user_path action
      rest.put path, params: params, auth: true do |response|
        response_handler response_handler, &ablock
      end
    end

    def get(action, params = {}, &ablock)
      path = user_path action, params
      rest.get path, auth: true do |response|
        response_handler response, &ablock
      end
    end

    def user_path(action, params = {})
      resource = params.delete(:resource) || 'user'
      path = "/api/v1/#{resource}/#{action}"
      # TODO: find a better way to handle multiple parameters, dig into HTTParty
      path += '?' if params.size.positive?
      params.each do |key, value|
        if value.is_a? Hash
          path += "#{key}=#{URI.escape(value.to_json)}&"
        else
          path += "#{key}=#{value}&"
        end
      end
      path
    end

    def response_handler(response, &ablock)
      if block_given?
        ablock.yield response
      else
        rest.response_handler response
      end
    end
  end
end
