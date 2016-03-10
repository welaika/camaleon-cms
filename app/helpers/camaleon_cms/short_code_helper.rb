=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::ShortCodeHelper
  # Internal method
  def shortcodes_init
    @_shortcodes = []
    @_shortcodes_template = {}
    @_shortcodes_descr = {}

    shortcode_add("widget", nil, "Renderize the widget content in this place.
                Don't forget to create and copy the shortcode of your widgets in appearance -> widgets
                Sample: [widget widget_key]")

    shortcode_add("load_libraries",
                  lambda{|attrs, args| cama_load_libraries(*attrs["data"].to_s.split(",")); return ""; },
                  "Permit to load libraries on demand, sample: [load_libraries data='datepicker,tinymce']")

    shortcode_add("asset",
                  lambda{|attrs, args|
                    url = attrs["as_path"].present? ? ActionController::Base.helpers.asset_url(attrs["file"]) : ActionController::Base.helpers.asset_url(attrs["file"])
                    if attrs["image"].present?
                      ActionController::Base.helpers.image_tag(attrs["file"], class: attrs["class"], style: attrs["style"])
                    else
                      url
                    end
                  },
                  "Permit to generate an asset url (
                    add file='' asset file path,
                    add as_path='true' to generate only the path and not the full url,
                    add class='my_class' to setup image class,
                    add style='height: 100px; width: 200px;...' to setup image style,
                    add image='true' to generate the image tag with this url),
                  sample: <img src=\"[asset as_path='true' file='themes/my_theme/assets/img/signature.png']\" /> or [asset image='true' file='themes/my_theme/assets/img/signature.png' style='height: 50px;']")

    shortcode_add("data",
                  lambda{|attrs, args|
                    cama_shortcode_data(attrs, args) rescue ""
                  },
                  "Permit to generate specific data of a post.
                  Attributes:
                    object: (String, defaut post) Model name: post | posttype | category | posttag | site | user |theme | navmenu
                    id: (Integer) Post id
                    key: (String) Post slug
                    field: (String) Custom field key, you can add render_field='true' to render field as html element, also you can add index=2 to indicate the value in position 2 for multitple values
                    attrs: (String) attribute name
                            post: title | created_at | excerpt | url | link | thumb | updated_at | author_name | author_url
                            posttype: title | created_at | excerpt | url | link | thumb | updated_at
                            category: title | created_at | excerpt | url | link | thumb | updated_at
                            posttag: title | created_at | excerpt | url | link | thumb | updated_at
                            site: title | created_at | excerpt | url | link | thumb | updated_at
                            user: title | created_at | excerpt | url | link | thumb | updated_at
                            theme: title | created_at | excerpt | url | link | thumb | updated_at
                            navmenu: title | created_at | excerpt | url | link | thumb | updated_at
                    Note: If id and key is not present, then will be rendered for current model
                  Sample:
                    [data id='122' attr='title'] ==> return the title of post with id = 122
                    [data key='contact' attr='url'] ==> return the url of post with slug = contact
                    [data key='contact' attr='link'] ==> return the link with title as text of the link of post with slug = contact
                    [data object='site' attr='url'] ==> return the url of currrent site
                    [data key='page' object='posttype' attr='url'] ==> return the url of post_type with slug = page
                    [data field=icon index=2] ==> return the second value (multiple values) for this custom field with key=icon of current object
                    [data key='contact' field='sub_title'] ==> return the value of the custom_field with key=sub_title registered for post.slug = contact
                    [data object='site' field='sub_title'] ==> return the value of the custom_field with key=sub_title registered for current_site")
  end

  # add shortcode
  # key: shortcode key
  # template: template to render, if nil will render "shortcode_templates/<key>"
  # Also can be a function to execute that instead a render, sample: lambda{|attrs, args| return "my custom content"; }
  # descr: description for shortcode
  def shortcode_add(key, template = nil, descr = '')
    @_shortcodes << key
    @_shortcodes_template = @_shortcodes_template.merge({"#{key}"=> template}) if template.present?
    @_shortcodes_descr[key] = descr if descr.present?
  end

  # add or update shortcode template
  # key: chortcode key to add or update
  # template: template to render, if nil will render "shortcode_templates/<key>"
  def shortcode_change_template(key, template = nil)
    @_shortcodes_template[key] = template
  end

  # delete shortcode
  # key: chortcode key to delete
  def shortcode_delete(key)
    @_shortcodes.delete(key)
  end

  # run all shortcodes in the content
  # content: (string) text to find a short codes
  # args: custom arguments to pass for short codes render, sample: {owner: my_model, a: true}
  #   if args != Hash, this will re send as args = {owner: args}
  #   args should be include the owner model who is doing the action to optimize DB queries
  # sample: do_shortcode("hello [greeting 'world']!", @my_post) ==> "hello world!"
  # sample: do_shortcode("hello [greeting 'world']", {attr1: 'asd', owner: @my_post})
  # return rendered string
  def do_shortcode(content, args = {})
    args = {owner: args} unless args.is_a?(Hash)
    content.scan(/#{cama_reg_shortcode}/) do |item|
      shortcode, code, space, attrs = item
      content = content.sub(shortcode, _eval_shortcode(code, attrs, args))
    end
    content
  end

  # remove all shortcodes from text
  # Arguments
  #   text: String that contains shortcodes
  # return String
  def cama_strip_shortcodes(text)
    text.gsub(/#{cama_reg_shortcode}/, "")
  end

  # render direct a shortcode
  # text: text that contain the shortcode
  # key: shortcode key
  # template: template to render, if nil this will render default render file
  # Also can be a function to execute that instead a render, sample: lambda{|attrs, args| return "my custom content"; }
  # render_shortcode("asda dasdasdas[owen a='1'] [bbb] sdasdas dasd as das[owen a=213]", "owen", lambda{|attrs, args| puts attrs; return "my test"; })
  def render_shortcode(text, key, template = nil)
    text.scan(/#{cama_reg_shortcode(key)}/).each do |item|
      shortcode, code, space, attrs = item
      text = text.sub(shortcode, _eval_shortcode(code, attrs, {}, template))
    end
    text
  end

  private
  # create the regexpression for shortcodes
  # codes: (String) shortcode keys separated by |
  # sample: load_libraries|asset
  # if empty, codes will be replaced with all registered shortcodes
  # Return: (String) reg expression string
  def cama_reg_shortcode(codes = nil)
    "(\\[(#{codes || @_shortcodes.join("|")})(\s|\\]){1}(.*?)\\])"
  end

  # determine the content to replace instead the shortcode
  # return string
  def _eval_shortcode(code, attrs, args={}, template = nil)
    template ||= (@_shortcodes_template[code].present? ? @_shortcodes_template[code] : "camaleon_cms/shortcode_templates/#{code}")
    if @_shortcodes_template[code].class.name == "Proc"
      res = @_shortcodes_template[code].call(_shortcode_parse_attr(attrs), args)
    else
      res = render :file => template, :locals => {attributes: _shortcode_parse_attr(attrs), args: args}
    end
    res
  end

  # parse the attributes of a shortcode
  def _shortcode_parse_attr(text)
    res = {}
    return res unless text.present?
    text.scan(/(\w+)\s*=\s*"([^"]*)"(?:\s|$)|(\w+)\s*=\s*\'([^\']*)\'(?:\s|$)|(\w+)\s*=\s*([^\s\'"]+)(?:\s|$)|"([^"]*)"(?:\s|$)|(\S+)(?:\s|$)/).each do |item|
      item.each_with_index do |c, index|
        if c.present?
          res[c] = item[index+1]
          break
        end
      end
    end
    res
  end

  # execute shortcode data
  def cama_shortcode_data(attrs, args)
    res = ""
    object = attrs["object"].downcase || "post"
    attr = attrs["attr"] || "title"
    if (args[:owner].present? && object == args[:owner].class.name.parseCamaClass.downcase) || !attrs["object"].present?
      model = args[:owner]
    else
      model = cama_shortcode_model_parser(object, attrs) || args[:owner]
    end
    return res unless model.present?
    
    if attrs["field"].present? # model custom fields
      field = model.get_field_object(attrs["field"])
      if attrs["render_field"].present?
        return render :file => "custom_fields/#{field.options["field_key"]}", :locals => {object: model, field: field, field_key: attrs["field"], attibutes: attrs}
      else
        if attrs["index"]
          res = model.the_fields(attrs["field"])[attrs["index"].to_i-1] rescue ""
        else
          res = model.the_field(attrs["field"])
        end
        return res
      end

    else # model attributes
      case attr
        when "title"
          res = model.the_title
        when "created_at"
          res = model.the_created_at
        when "updated_at"
          res = model.the_updated_at
        when "excerpt"
          res = model.the_excerpt rescue ""
        when "url"
          res = model.the_url rescue ""
        when "link"
          res = model.the_link rescue ""
        when "thumb"
          case object
            when "site"
              res =  model.the_logo
            when "user"
              res =  model.the_avatar
            else
              res =  model.the_thumb_url
          end
        else
          case object
            when 'site'
              case attr
                when "title"
                when "title"
              end
            when 'post'
              case attr
                when "author_name"
                  res = model.the_author.the_name rescue ''
                when "author_url"
                  res = model.the_author.the_name rescue ''
              end
          end
      end
    end
    res
  end

  # return the model object according to the type
  def cama_shortcode_model_parser(object, attrs)
    model = nil
    case object.downcase
      when "post"
        model = current_site.the_post(attrs["id"].to_i) if attrs["id"].present?
        model = current_site.the_post(attrs["key"].to_s) if attrs["key"].present?

      when "posttype"
        model = current_site.the_post_type(attrs["id"].to_i) if attrs["id"].present?
        model = current_site.the_post_type(attrs["key"].to_s) if attrs["key"].present?

      when "category"
        model = current_site.the_category(attrs["id"].to_i) if attrs["id"].present?
        model = current_site.the_category(attrs["key"].to_s) if attrs["key"].present?

      when "posttag"
        model = current_site.the_tag(attrs["id"].to_i) if attrs["id"].present?
        model = current_site.the_tag(attrs["key"].to_s) if attrs["key"].present?

      when "site"
        model = current_site

      when "theme"
        model = current_theme

      when "navmenu"
        model = current_site.nav_menu_items.find(attrs["id"]) if attrs["id"].present?
        model = current_site.nav_menu_items.find_by_slug(attrs["key"]) if attrs["key"].present?

      when "user"
        model = current_site.the_user(attrs["id"].to_i) if attrs["id"].present?
        model = current_site.the_user(attrs["key"].to_s) if attrs["key"].present?
    end
    model
  end
end
