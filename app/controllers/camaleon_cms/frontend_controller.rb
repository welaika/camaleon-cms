=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::FrontendController < CamaleonCms::CamaleonController
  include CamaleonCms::FrontendConcern
  prepend_before_action :init_frontent
  prepend_before_action :cama_site_check_existence
  include CamaleonCms::Frontend::ApplicationHelper
  layout Proc.new { |controller| params[:cama_ajax_request].present? ? "cama_ajax" : 'index' }

  before_action :before_hooks
  after_action :after_hooks
  # rescue_from ActiveRecord::RecordNotFound, with: :page_not_found

  # home page for frontend
  def index
    @cama_visited_home = true
    if @_site_options[:home_page].present?
      render_post(@_site_options[:home_page].to_i)
    else
      r = {layout: (self.send :_layout), render: "index"}
      hooks_run("on_render_index", r)
      render r[:render], layout: r[:layout]
    end
  end

  # render category list
  def category
    begin
      @category = current_site.the_full_categories.find(params[:category_id]).decorate
      @post_type = @category.the_post_type
    rescue
      return page_not_found
    end
    @cama_visited_category = @category
    @children = @category.children.no_empty.decorate
    @posts = @category.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    r_file = lookup_context.template_exists?("categories/#{@category.the_slug}") ? "categories/#{@category.the_slug}" : "category"
    layout_ = lookup_context.template_exists?("layouts/categories/#{@category.the_slug}") ? "categories/#{@category.the_slug}" : (self.send :_layout)
    r = {category: @category, layout: layout_, render: r_file}; hooks_run("on_render_category", r)
    render r[:render], layout: r[:layout]
  end

  # render contents from post type
  def post_type
    begin
      @post_type = current_site.post_types.find(params[:post_type_id]).decorate
    rescue
      return page_not_found
    end
    @cama_visited_post_type = @post_type
    @posts = @post_type.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    @categories = @post_type.categories.no_empty.eager_load(:metas).decorate
    @post_tags = @post_type.post_tags.eager_load(:metas)
    r_file = lookup_context.template_exists?("post_types/#{@post_type.the_slug}") ? "post_types/#{@post_type.the_slug}" : "post_type"
    layout_ = lookup_context.template_exists?("layouts/post_types/#{@post_type.the_slug}") ? "post_types/#{@post_type.the_slug}" : (self.send :_layout)
    r = {post_type: @post_type, layout: layout_, render: r_file};  hooks_run("on_render_post_type", r)
    render r[:render], layout: r[:layout]
  end

  # render contents for the post tag
  def post_tag
    begin
      @post_tag = current_site.post_tags.find(params[:post_tag_id]).decorate
      @post_type = @post_tag.the_post_type
    rescue
      return page_not_found
    end
    @cama_visited_tag = @post_tag
    @posts = @post_tag.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    r_file = lookup_context.template_exists?("post_tags/#{@post_tag.the_slug}") ? "post_tags/#{@post_tag.the_slug}" : "post_tag"
    layout_ = lookup_context.template_exists?("layouts/post_tags/#{@post_tag.the_slug}") ? "post_tags/#{@post_tag.the_slug}" : (self.send :_layout)
    r = {post_tag: @post_tag, layout: layout_, render: r_file}; hooks_run("on_render_post_tag", r)
    render r[:render], layout: r[:layout]
  end

  # search contents
  def search
    breadcrumb_add(ct("search"))
    @cama_visited_search = true
    @param_search = params[:q]
    layout_ = lookup_context.template_exists?("layouts/search") ? "search" : (self.send :_layout)
    r = {layout: layout_, render: "search", posts: nil}; hooks_run("on_render_search", r)
    params[:q] = (params[:q] || '').downcase
    @posts = r[:posts] != nil ? r[:posts] : current_site.the_posts.where("LOWER(title) LIKE ? OR LOWER(content_filtered) LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    @posts_size = @posts.size
    @posts = @posts.paginate(:page => params[:page], :per_page => current_site.front_per_page)
    render r[:render], layout: r[:layout]
  end

  # ajax requests
  def ajax
    r = {render_file: nil, render_text: "", layout: (self.send :_layout) }
    @cama_visited_ajax = true
    hooks_run("on_ajax", r)
    if r[:render_file]
      render r[:render_file], layout: r[:layout]
    else
      render inline: r[:render_text]
    end
  end

  # render a post
  def post
    if params[:draft_id].present?
      draft_render
    else
      render_post(@post || params[:slug].to_s.split("/").last, true)
    end
  end

  # render user profile
  def profile
    begin
      @user = current_site.users.find(params[:user_id]).decorate
    rescue
      return page_not_found
    end
    @cama_visited_profile = true
    layout_ = lookup_context.template_exists?("layouts/profile") ? "profile" : (self.send :_layout)
    r = {user: @user, layout: layout_, render: "profile"};  hooks_run("on_render_profile", r)
    render r[:render], layout: r[:layout]
  end

  private
  # render a post from draft
  def draft_render
    post_draft = current_site.posts.drafts.find(params[:draft_id])
    if can?(:update, post_draft)
      render_post(post_draft)
    else
      page_not_found
    end
  end

  # render a post
  # post_or_slug_or_id: slug_post | id post | post object
  # from_url: true/false => true (true, permit eval hooks "on_render_post")
  def render_post(post_or_slug_or_id, from_url = false)
    if post_or_slug_or_id.is_a?(String) # slug
      @post = current_site.the_posts.find_by_slug(post_or_slug_or_id)
    elsif post_or_slug_or_id.is_a?(Integer) # id
      @post = current_site.the_posts.where(id: post_or_slug_or_id).first
    else # model
      @post = post_or_slug_or_id
    end

    unless @post.present?
      if params[:format] == 'html' || !params[:format].present?
        page_not_found()
      else
        render nothing: true, status: 404
      end
    else
      @post = @post.decorate
      @cama_visited_post = @post
      @post_type = @post.the_post_type
      @comments = @post.the_comments
      @categories = @post.the_categories
      @post.increment_visits!
      home_page = @_site_options[:home_page] rescue nil
      if lookup_context.template_exists?("page_#{@post.id}")
        r_file = "page_#{@post.id}"
      elsif @post.get_template(@post_type).present? && lookup_context.template_exists?(@post.get_template(@post_type))
        r_file = @post.get_template(@post_type)
      elsif home_page.present? && @post.id.to_s == home_page
        r_file = "index"
      elsif lookup_context.template_exists?("#{@post_type.slug}")
        r_file = "#{@post_type.slug}"
      else
        r_file = "single"
      end

      layout_ = self.send :_layout
      meta_layout = @post.get_layout(@post_type)
      layout_ = meta_layout if meta_layout.present? && lookup_context.template_exists?("layouts/#{meta_layout}")
      r = {post: @post, post_type: @post_type, layout: layout_, render: r_file}
      hooks_run("on_render_post", r) if from_url
      render r[:render], layout: r[:layout]
    end
  end


  # render error page
  def page_not_found()
    if @_site_options[:error_404].present? # render a custom error page
      page_404 = current_site.posts.find(@_site_options[:error_404]) rescue ""
      if page_404.present?
        page_404 = page_404.decorate
        redirect_to page_404.the_url
        return
      end
    end
    render_error(404)
  end

  # define frontend locale
  # if url hasn't a locale, then it will use default locale set on application.rb
  def init_frontent
    # preview theme initializing
    if cama_sign_in? && params[:ccc_theme_preview].present? && can?(:manager, :themes)
      @_current_theme = (current_site.themes.where(slug: params[:ccc_theme_preview]).first_or_create!.decorate)
    end

    @_site_options = current_site.options
    I18n.locale = params[:locale] || current_site.get_languages.first
    return page_not_found unless current_site.get_languages.include?(I18n.locale.to_sym) # verify if this locale is available for this site

    # define render paths
    lookup_context.prefixes.delete("frontend")
    lookup_context.prefixes.delete("application")
    lookup_context.prefixes.delete("camaleon_cms/frontend")
    lookup_context.prefixes.delete("camaleon_cms/camaleon")

    if ['camaleon_cms/frontend', 'frontend'].include?(params[:controller]) # 'frontend' will be removed in new versions (move into camaleon_cms/frontend)
      lookup_context.prefixes.prepend("camaleon_cms/default_theme")
      lookup_context.prefixes.prepend("themes/#{current_theme.slug}") if current_theme.settings["gem_mode"]
      lookup_context.prefixes.prepend("themes/#{current_theme.slug}/views") unless current_theme.settings["gem_mode"]
      lookup_context.prefixes.prepend("themes/#{current_site.id}/views")
    end
    lookup_context.prefixes = lookup_context.prefixes.uniq
    theme_init()
  end

  # initialize hooks before to execute action
  def before_hooks
    hooks_run("front_before_load")
  end

  # initialize hooks after executed action
  def after_hooks
    hooks_run("front_after_load")
  end

  # define default options for url helpers
  # control for default locale
  def default_url_options(options = {})
    begin
      if current_site.get_languages.first.to_s == I18n.locale.to_s
        options
      else
        { locale: I18n.locale }.merge options
      end
    rescue
      options
    end
  end
end
