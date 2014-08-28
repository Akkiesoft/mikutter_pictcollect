# -*- coding: utf-8 -*-
require "open-uri"
require "FileUtils"

# From http://d.hatena.ne.jp/gan2/20080531/1212227507
def save_file(url, filename)
  open(filename, 'wb') do |file|
    open(url) do |data|
      file.write(data.read)
    end
  end
end

# From sub_parts_image plugin
# https://github.com/moguno/mikutter-subparts-image
# 画像URLを取得
def get_image_urls(message)
  target = []
  if message[:entities]
    target = message[:entities][:urls].map { |m| { :url => m[:expanded_url], :entity => m } }
    if message[:entities][:media]
      target += message[:entities][:media].map { |m| { :url => m[:media_url], :entity => m } }
    end
  end

  result = target.map { |entity|
    base_url = entity[:url]
    image_url = Plugin[:openimg].get_image_url(base_url)

    if image_url
      if base_url =~ /pbs\.twimg\.com/
        base_url =base_url+":orig"
      end
      {:page_url => base_url, :image_url => image_url, :entity => entity[:entity] }
    else
      nil
    end
  }.compact.sort { |a| a[:entity][:indices][0] } 
  result
end

def check_pictwitter(url)
  if url =~ /^https?\:\/\/pbs\.twimg\.com/
    if !url !~ /\:orig$/
      url = url+":orig"
    end
  end
  url
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
      if (! FileTest.exist?(savedir))
        raise "設定されているディレクトリが存在しません"
      end
      if savedir !=~ /\/$/
        savedir = savedir + "/"
      end

      # 選択されたツイートに対してそれぞれ実行
      opt.messages.each{ |message|
        # ツイートに含まれる画像のURLを取得してそれぞれ実行
        targets = get_image_urls(message)
        targets.each{ |target|
          # ほう、お前か
          imgurl = target[:image_url]
          # ファイル名の決定
          ext = File.extname(imgurl)
          target[:entity][:expanded_url] =~ %r{http://twitter.com/(.+)/status/(.+)/photo/([0-9]+)}
          filename = "#{savedir}#{$~[1]}_#{$~[2]}#{ext}"
          # だれがねえ！だれがpic.twitter.comの画像に:origつけてもおんなじや！おんなじや！思てえええ！！！
          imgurl = check_pictwitter(imgurl)
          # ふぅ
          save_file(imgurl, filename)
          activity :pictcollect, "ほぞんした！！"
        }
      }
    rescue => msg
      activity :pictcollect, msg.to_s
    end
  end
  
  settings "画像これくしょん" do
    input("画像を保存するディレクトリ",:collect_savedir)
  end

end

