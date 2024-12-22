# 画像これくしょん(mikutter3.6以降)

require "open-uri"
require 'net/http'
require 'uri'
require 'fileutils'

Plugin.create(:pictcollect) do
  defactivity "pictcollect", "画像これくしょん"

  def get_savedir()
    savedir = UserConfig[:collect_savedir]
    if (FileTest.exist?(savedir))
      # 保存先ディレクトリの取得と必要に応じて/の補完
      return savedir + "/" if savedir !=~ /\/$/
    else
      activity :pictcollect, "先に保存先ディレクトリを指定してください"
      return nil
    end
  end

  # From https://morizyun.github.io/ruby/tips-image-type-check-png-jpeg-gif.html
  def image_type(file_path)
    File.open(file_path, 'rb') do |f|
      begin
        header = f.read(12)
        f.seek(-12, IO::SEEK_END)
        footer = f.read(12)
      rescue
        return ''
      end

      if header[0, 2].unpack('H*') == %w(ffd8) && footer[-2, 2].unpack('H*') == %w(ffd9)
        return '.jpg'
      elsif header[0, 3].unpack('A*') == %w(GIF) && footer[-1, 1].unpack('H*') == %w(3b)
        return '.gif'
      elsif header[0, 8].unpack('H*') == %w(89504e470d0a1a0a) && footer[-12,12].unpack('H*') == %w(0000000049454e44ae426082)
        return '.png'
      elsif header[0, 12].unpack('A8A4')[1] == "WEBP"
        return '.webp'
      end
    end
    return ''
  end

  # From http://d.hatena.ne.jp/gan2/20080531/1212227507
  def save_file(url, filename)
    ret = Thread.new(url) { |url|
      if File.exist?(filename)
        activity :pictcollect, "もうある #{filename}"
        Thread.exit
      end
      saved = false
      begin
        open(filename, 'wb') do |file|
          URI.open(url) do |data|
            file.write(data.read)
          end
          saved = true
      rescue OpenURI::HTTPError => e
          activity :pictcollect, "ほぞんできないURL #{url} (#e)"
        end
      end
      # # 拡張子を含まない場合は調べて付加する
      # if (File.extname(filename) !~ /\.(jpg|jpeg|png|webp|gif|mp4)$/ )
      #   old = filename
      #   ext = image_type(filename)
      #   if ext != ""
      #     filename += ext
      #     if File.exist?(filename)
      #       File.delete(old)
      #       activity :pictcollect, "もうある #{filename}"
      #     else
      #       File.rename(old, filename)
      #     end
      #   else
      #     File.delete(filename)
      #     activity :pictcollect, "ほぞんできないURL #{url}"
      #     saved = nil
      #   end
      # end
      if saved
        activity :pictcollect, "ほぞんした！！ #{url} --> #{filename}"
      end
    }
  end

  def pictcollect_mastodon(message)
    attachments = message.media_attachments
    if not attachments.count
      return
    end
    username = message.account.acct
    post_id = message.uri.to_s.split("/")[-1]
    savedir = prepare_directory("mastodon", username)
    attachments.each_with_index { | attach, i |
      url = attach.remote_url ? attach.remote_url : attach.url
      ext = File.extname(url)
      ext = (ext.include?("?")) ? ext.split("?")[0] : ext
      filename = "#{savedir}/#{username}_#{post_id}_#{i + 1}#{ext}"
      save_file(url, filename)
    }
  end

  def prepare_directory(world, username)
    savedir_opt = "#{world}"
    # ユーザーごとにディレクトリを掘る場合
    if UserConfig[:collect_mkdir_by_initial]
      initial = username[0].upcase
      savedir_opt += "/#{initial}"
    end
    if UserConfig[:collect_mkdir_by_account]
      savedir_opt += "/#{username}"
    end

    savedir = get_savedir() + savedir_opt
    if (! Dir.exist?(savedir))
      FileUtils.mkdir_p(savedir)
    end
    savedir
  end

  command(
    :pictcollect,
    name: '画像をこれくしょんする',
    condition: lambda{ |opt| true },
    visible: true,
    role: :timeline
  ) do |opt|
    begin
      # 選択されたツイートに対してそれぞれ実行
      opt.messages.each { |message|
        case message.class.slug
        when :mastodon_status, :worldon_status
          pictcollect_mastodon(message)
        else
          activity :pictcollect, "未対応のWorldです"
          return
        end
      }
    rescue => msg
      activity :pictcollect, msg.to_s
    end
  end

  command(:bulk_collect,
    name: 'まとめて画像これくしょん',
    condition: lambda{ |opt| true },
    visible: true,
    role: :postbox
  ) do |opt|
    savedir = get_savedir()
    next unless (savedir)

    urls = Plugin[:gtk3].widgetof(opt.widget).widget_post.buffer.text
    Plugin[:gtk3].widgetof(opt.widget).widget_post.buffer.text = ""
    urls.each_line(chomp: true) { |url|
      # 金具さんのshow_tweetをパクった
      # https://github.com/cobodo/show_tweet/blob/req/any-model/show_tweet.rb
      diva_url = Diva::URI.new(url)
      model_class = Enumerator.new { |y|
        Plugin.filtering(:model_of_uri, diva_url, y)
      }.lazy.map{ |model_slug|
        Diva::Model(model_slug)
      }.find{ |mc|
        mc.spec.timeline
      }
      Delayer.Deferred.new{
        model_class.find_by_uri(diva_url)
      }.next{ |message|
          pictcollect(message, savedir)
      }.terminate {|e|
          activity :pictcollect, "このツイートはこれくしょんできませんでした #{url} -> #{e.to_s}"
      }
    }
  end

  settings "画像これくしょん" do
    input("画像を保存するディレクトリ", :collect_savedir)
    boolean('アカウントごとにディレクトリを作成', :collect_mkdir_by_account)
    boolean('アカウントの頭文字ごとにディレクトリを作成', :collect_mkdir_by_initial)
  end

end
