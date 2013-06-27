class ApiController < ApplicationController
	require 'json'

  def list
    arr = ["websummit.net","startseries.com","pubsummit.com","f.ounders.com"]
    params[:domain] = 'websummit.net' if params[:domain] == 'www.websummit.net' || params[:domain] == 'websummit1.net.hammer.dev'
    if arr.include? params[:domain]
      dropbox = connect
      path = "Sites1/#{params[:domain]}/Build/#{params[:path]}".gsub(/\/\//, '/')
      file = dropbox.download path
      doc = Nokogiri::HTML(file)
      array = []
      arr = doc.css('[data-editable]')
      arr.each do |elem|
        obj = {
          :"data-editable" => elem['data-editable'],
          :"data-original" => elem.text
        }
        array << obj
      end
      render :json => {
        :success => true,
        :array => array
      }
    end
  end

  def update
    dropbox = connect
    params[:domain] = 'websummit.net' if params[:domain] == 'www.websummit.net' || params[:domain] == 'websummit1.net.hammer.dev'
    path = "Sites1/#{params[:domain]}/#{params[:path]}".gsub(/\/\//, '/')
    split = path.split('.')
    split[-1] = 'haml' if split[-1] == 'html'
    path = split.join('.')
    puts "path #{path}"
    file = dropbox.download path
    params["changes"].each_value do |change|
      name = change["name"]
      puts "name #{name}"
      value = change["value"]
      puts "vale #{value}"
      regex = /<!-- \$#{name} .* -->/
      replace = "<!-- $#{name} #{value} -->"
      #modify
      file.gsub!(regex, replace)
    end
    dropbox.upload path, file
    regex [path]
    render :nothing => true
  end

  def regex paths
    dropbox = connect
    reg = /<!-- \$.* -->/
    paths.each do |path|
      puts " "
      puts path
      puts "====="
      puts " "
      file = dropbox.download path
      # find variables, find each on page, ensure data-editable is there.
      arr = file.scan(reg)
      arr.each do |element|
        elem = element[6..-5].split.first
        if element =~ /<!-- \$#{elem} -->/
          #this is where it's used.
          r1 = /.*\{.*\} <!-- \$#{elem} -->/
          r2 = /.*\{.*:"data-editable" => ".*" .*\} <!-- \$#{elem} -->/
          r3 = /.*\{.*:"data-editable" => "#{elem}".*\} <!-- \$#{elem} -->/
          
          rbreak1 = /.*\{.*\}\r\n\t?|\n\t<!-- \$#{elem} -->/
          rbreak2 = /.*\{.*:"data-editable" => ".*" .*\}\r\n\t?|\n\t<!-- \$#{elem} -->/
          rbreak3 = /.*\{.*:"data-editable" => "#{elem}".*\}\r\n\t?|\n\t<!-- \$#{elem} -->/
          rbreak4 = /.*\n\t<!-- \$#{elem} -->/
          puts "check #{file =~ rbreak4}"
          puts ""
          if file =~ r3
            #done
          elsif file =~ r2
            m = file.match(r2)
            params = /{(.*)}/
            str = m.to_a.first.match(params).to_a.first
            str = "{#{str}}"
            hash = to_hash str
            hash1 = to_hash str
            hash1['data-editable'] = '.*' #for regex
            hash['data-editable'] = elem
            # different data-editable
            file.gsub!(/#{hash1} <!-- \$#{elem} -->/, "#{hash} <!-- \$#{elem} -->")
            puts " "
          elsif file =~ r1
            m = file.match(r1)
            params = /{(.*)}/
            str = m.to_a.first.match(params).to_a.first
            str = "{#{str}}"
            # brackets but no data-editable
            hash = to_hash str
            hash1 = to_hash str
            hash[:'data-editable'] = elem
            file.gsub!(/#{output_hash hash1} <!-- \$#{elem} -->/, "#{output_hash hash} <!-- \$#{elem} -->")
          elsif file =~ rbreak3
          elsif file =~ rbreak2
            m = file.match(r2)
            params = /{(.*)}/
            str = m.to_a.first.match(params).to_a.first
            str = "{#{str}}"
            hash = to_hash str
            hash1 = to_hash str
            hash1['data-editable'] = '.*' #for regex
            hash['data-editable'] = elem
            # different data-editable
            file.gsub!(/#{hash1}\r\n\t?|\n\t<!-- \$#{elem} -->/, "#{hash}\n\t<!-- \$#{elem} -->")
            puts " "
          elsif file =~ rbreak1
            m = file.match(r1)
            params = /{(.*)}/
            str = m.to_a.first.match(params).to_a.first
            str = "{#{str}}"
            # brackets but no data-editable
            hash = to_hash str
            hash1 = to_hash str
            hash[:'data-editable'] = elem
            file.gsub!(/#{output_hash hash1}\r\n\t?|\n\t<!-- \$#{elem} -->/, "#{output_hash hash}\n\t<!-- \$#{elem} -->")
          elsif file =~ rbreak4
            # no brackets at all.
            hash = {}
            hash[:'data-editable'] = elem
            file.gsub!(/\r\n\t?|\n\t<!-- \$#{elem} -->/, "#{output_hash hash}\n\t<!-- \$#{elem} -->")
          else
            # no brackets at all.
            hash = {}
            hash[:'data-editable'] = elem
            file.gsub!(/ <!-- \$#{elem} -->/, "#{output_hash hash} <!-- \$#{elem} -->")
          end
        end
      end
      dropbox.upload path, file
    end
  end

  def cron 
    dropbox = connect
    paths = add_to_array(dropbox.ls('Sites1'))
    regex paths
    render :nothing => true
  end


  protected

    def add_to_array ls
      arr = []
      if !ls.blank?
        ls.each do |x|
          next if (x["path"].split('.')[-1] != 'haml' && !x["is_dir"]) #check for Build folder
          tmp = (x["is_dir"]) ? add_to_array(x.ls) : x.path
          arr << tmp
        end
      end
      arr.flatten
    end

    def output_hash h
      "#{h}".gsub!('=>',' => ')
    end


    def to_hash s
      s.gsub(/[{}:]/,'').split(', ').map{|h| h1,h2 = h.split('=>'); {h1.strip.chomp("'").reverse.chomp("'").reverse.chomp('"').reverse.chomp('"').reverse => h2.strip.chomp("'").reverse.chomp("'").reverse.chomp('"').reverse.chomp('"').reverse}}.reduce(:merge).symbolize_keys!
    end
end
