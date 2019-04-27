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
    logger.error("[error] users#index11")
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)

    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = {
            type: 'text',
            text: event.message['text']
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    # events.each { |event|
    #   case event
    #   when Line::Bot::Event::Message
    #     handle_message(event)
    #   end
    # }
    head :ok
  end

  def handle_message(event)
    case event.type
    when Line::Bot::Event::MessageType::Text
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
        message = {
          type: 'text',
          text: event.message['text']
        }
        client.reply_message(event['replyToken'], message)
      end
    end
  end
end
