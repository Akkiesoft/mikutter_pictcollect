# -*- coding: utf-8 -*-
require "open-uri"
require "FileUtils"

# From http://d.hatena.ne.jp/gan2/20080531/1212227507
def save_file(url, filename)
  # これより、ファイルを開きます
  open(filename, 'wb') do |file|
    open(url) do |data|
      file.write(data.read)
    end
  end
end

# ご着席をお願いいたします
# （落ち着け、pic.twitter.comは:origをつけると元のファイルが落とせる）
def check_pictwitter(url)
  if url =~ /^https?\:\/\/pbs\.twimg\.com/
    if !url !~ /\:orig$/
      url = url+":orig"
    end
  end
  url
end

# From sub_parts_image plugin
# https://github.com/moguno/mikutter-subparts-image
# メッセージに含まれるURLとエンティティを抽出する
def extract_urls_by_message(message)
  entities = [
    { :symbol => :entities, :filter => lambda { |images| images.sort { |_| _[:entity][:indices][0] } } },
    { :symbol => :extended_entities, :filter => nil },
  ]

  targets = entities.inject([]) { |result, entities|
    symbol = entities[:symbol]

    if message[symbol]
      if message[symbol][:urls]
        result += message[symbol][:urls].map { |m| { :url => m[:expanded_url], :entity => m } }
      end

      if message[symbol][:media]
        result += message[symbol][:media].map { |m| { :url => m[:media_url], :entity => m } }
      end
    end

    if entities[:filter]
      entities[:filter].call(result)
    else
      result
    end
  }

  targets.uniq { |_| _[:url] }
end

# From sub_parts_image plugin
# https://github.com/moguno/mikutter-subparts-image
# 画像URLを取得
def get_image_urls(message)
  target = extract_urls_by_message(message)

  result = target.map { |entity|
    base_url = entity[:url]
    image_url = Plugin[:openimg].get_image_url(base_url)

    if image_url
    　base_url = check_pictwitter(base_url)
      {:page_url => base_url, :image_url => image_url, :entity => entity[:entity] }
    else
      nil
    end
  }.compact
  result
end

Plugin.create(:mikutter_pictcollect) do
  defactivity "pictcollect", "画像これくしょん"
  
  command(
          :mikutter_pictcollect,
          name: '画像をコレクションする',
          condition: lambda{ |opt| true },
          visible: true,
          role: :timeline
  ) do |opt|
    begin
      # 保存先ディレクトリの取得と必要に応じて/の補完
      savedir = UserConfig[:collect_savedir]
      # true か false で答えてください
      if (! FileTest.exist?(savedir))
        #あなたはね疑惑のエラーと呼ばれてるけど疑惑の総合商社ですよ！
        raise "設定されているディレクトリが存在しません"
      end
      if savedir !=~ /\/$/
        savedir = savedir + "/"
      end

      # 選択されたツイートに対してそれぞれ実行
      opt.messages.each { |message|
        # ツイートに含まれる画像のURLを取得してそれぞれ実行
        targets = get_image_urls(message)
        targets.each_with_index { |target, i|
          # ほう、お前か
          imgurl = target[:image_url]
          # ファイル名の決定
          ext = File.extname(imgurl)
          target[:entity][:expanded_url] =~ %r{http://twitter.com/(.+)/status/(.+)/photo/([0-9]+)}
          filename = "#{savedir}#{$~[1]}_#{$~[2]}_#{i+1}#{ext}"
          # だれがねえ！だれがpic.twitter.comの画像に:origつけてもおんなじや！おんなじや！思てえええ！！！
          imgurl = check_pictwitter(imgurl)
          # ふぅ
          save_file(imgurl, filename)
          activity :pictcollect, "ほぞんした！！ #{filename}"
        }
      }
    rescue => msg
      # 嘘！TLで全世界の人が見てるんです！
      activity :pictcollect, msg.to_s
    end
  end
  
  settings "画像これくしょん" do
    input("画像を保存するディレクトリ",:collect_savedir)
  end

end
# 以上を持ちまして、画像これくしょんプラグインに対する記述は、終了いたしました
