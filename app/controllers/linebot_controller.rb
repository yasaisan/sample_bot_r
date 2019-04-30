class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def reply_text(event, texts)
    texts = [texts] if texts.is_a?(String)
    client.reply_message(
      event['replyToken'],
      texts.map { |text| {type: 'text', text: text} }
    )
  end

  def reply_content(event, messages)
    res = client.reply_message(
      event['replyToken'],
      messages
    )
    puts res.read_body if res.code != 200
  end

  # スタート
  def callback
    body = request.body.read
    # logger.info("[info] y------------------------------------------------")
    # puts "aaaa"
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)

    events.each { |event|
      case event
      when Line::Bot::Event::Message
        handle_message(event)
      end
    }
    head :ok
  end

  def handle_message(event)
    case event.type
    when Line::Bot::Event::MessageType::Text

      # convert_message = transrate_message(event.message['text'])

      case event.message['text']
      when 'profile'
        if event['source']['type'] == 'user'
          profile = client.get_profile(event['source']['userId'])
          profile = JSON.parse(profile.read_body)
          reply_text(event, [
            "Display name\n#{profile['displayName']}",
            "Status message\n#{profile['statusMessage']}",
            "User ID\n#{profile['userId']}"
          ])
        else
          reply_text(event, "Bot can't use profile API without user ID")
        end
      when 'touroku'
        reply_content(event, {
          type: 'template',
          altText: '登録しますか？',
          template: {
            type: 'confirm',
            text: '登録しますか？',
            actions: [
              { label: 'Yes', type: 'message', text: 'Yes!' },
              { label: 'No', type: 'message', text: 'No!' },
            ],
          }
        })
      when 'Yes!'
        if event['source']['type'] == 'user'
          @user = User.new
          @user.userId = event['source']['userId']
          @user.save
          reply_text(event, [
            "User ID\n#{event['source']['userId']}を登録しました。"
          ])
        end
      else
        convert_message = transrate_ja_message(event.message['text'])
        get_google_image(event.message['text'])
        message = {
          type: 'text',
          text: convert_message
        }
        client.reply_message(event['replyToken'], message)
      end
    end
  end

  def transrate_ja_message(msg)
    require 'net/https'
    require 'uri'
    require 'cgi'
    require 'json'
    require 'securerandom'

    # **********************************************
    # *** Update or verify the following values. ***
    # **********************************************

    # Replace the key string value with your valid subscription key.
    key = '351118560b1a45929f0d91492722b4af'

    host = 'https://api.cognitive.microsofttranslator.com'
    path = '/translate?api-version=3.0'
    
    # Translate to German and Italian.
    params = '&to=ja'
    
    uri = URI (host + path + params)
    
    text = 'Hello, world!'
    
    content = '[{"Text" : "' + msg + '"}]'
    
    request = Net::HTTP::Post.new(uri)
    request['Content-type'] = 'application/json'
    request['Content-length'] = content.length
    request['Ocp-Apim-Subscription-Key'] = key
    request['X-ClientTraceId'] = SecureRandom.uuid
    request.body = content
    
    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request (request)
    end
    
    result = response.body.force_encoding("utf-8")
    
    # json = JSON.pretty_generate(JSON.parse(result))
    jsonParse = JSON.parse(result)
    # logger.debug (json)
    ranslation_lan = jsonParse[0]['translations'][0]['text']
    # puts json
    # logger.debug (result.to_yaml)
    # logger.debug (JSON.parse(result))
    # json.each do |value|
    #   # print(youso, "¥n")
    #   logger.debug (value)
    # end
    logger.debug (jsonParse[0])
    logger.debug (ranslation_lan)

    return ranslation_lan
  end

  def get_google_image(word)
    # baseurl = "https://www.googleapis.com/customsearch/v1?"
    # baseurl .= "key=AIzaSyCqe72UGyiLECERkWVTvOLXdFJxYvVspTI&cx=016901115011056515106:6pjbegaiuga&searchType=image&q="
    # get_img_url = $baseurl . urlencode($word)
    require 'google/apis/customsearch_v1'

    api_key = 'AIzaSyCqe72UGyiLECERkWVTvOLXdFJxYvVspTI'
    cse_id = '016901115011056515106:6pjbegaiuga'

    searcher = Google::Apis::CustomsearchV1::CustomsearchService.new
    searcher.key = api_key
    logger.debug ("searchWord = " + word)
    print "QUERY> "
    query = gets.chomp

    results = searcher.list_cses(word, cx: cse_id)
    items = results.items
    pp items.map {|item| { title: item.title, link: item.link} }
  end
  # function google_image($word) {
  #   // TODO: キーの外だし
  #   $baseurl = "https://www.googleapis.com/customsearch/v1?";
  #   $baseurl .= "key=AIzaSyCqe72UGyiLECERkWVTvOLXdFJxYvVspTI&cx=016901115011056515106:6pjbegaiuga&searchType=image&q=";
  #   $myurl = $baseurl . urlencode($word);
  #   $myjson = file_get_contents($myurl);
  #   $recs = json_decode($myjson, true);
  #   return $recs;
  # }
end