=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class PostType < TermTaxonomy
  default_scope { where(taxonomy: :post_type) }

  has_many :metas, ->{ where(object_class: 'PostType')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :categories, :class_name => "Category", foreign_key: :parent_id, dependent: :destroy
  has_many :post_tags, :class_name => "PostTag", foreign_key: :parent_id, dependent: :destroy
  has_many :posts, class_name: "Post", foreign_key: :taxonomy_id, dependent: :destroy
  has_many :posts_draft, class_name: "Post", foreign_key: :taxonomy_id, dependent: :destroy, source: :drafts
  has_many :field_group_taxonomy, -> {where("object_class LIKE ?","PostType_%")}, :class_name => "CustomField", foreign_key: :objectid, dependent: :destroy

  belongs_to :owner, class_name: "User", foreign_key: :user_id
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id

  scope :visible_menu, -> {where(term_group: nil)}
  scope :hidden_menu, -> {where(term_group: -1)}
  before_destroy :destroy_field_groups
  after_create :set_default_site_user_roles


  # check if current post type manage categories
  def manage_categories?
    options[:has_category]
  end

  # hide or show this post type on admin -> contents -> menu
  # true => enable, false => disable
  def toggle_show_for_admin_menu(flag)
    self.update(term_group: flag == true ? nil : -1)
  end

  # check if this post type is shown on admin -> contents -> menu
  def show_for_admin_menu?
    self.term_group == nil
  end

  # check if this post type manage post tags
  def manage_tags?
    options[:has_tags]
  end

  # assign settings for this post type
  # default values: {
  #   has_category: false,
  #   has_tags: false,
  #   has_summary: true,
  #   has_content: true,
  #   has_comments: false,
  #   has_picture: true,
  #   has_template: true,
  #   has_keywords: true
  # }
  def set_settings(settings = {})
    settings.each do |key, val|
      self.set_setting(key, val)
    end
  end

  # set or update a setting for this post type
  def set_setting(key, value)
    self.set_option(key, value)
  end

  # select full_categories for the post type, include all children categories
  def full_categories
    s = self.site
    Category.where("term_group = ? or status in (?)", s.id, s.post_types.pluck(:id).to_s)
  end

  # return default category for this post type
  # only return a category for post types that manage categories
  def default_category
    if manage_categories?
      cat = self.categories.find_by_slug("uncategorized")
      unless cat.present?
        cat = self.categories.create({name: 'Uncategorized', slug: 'uncategorized', parent: self.id})
        cat.set_option("not_deleted", true)
      end
      cat
    end
  end

  # add a post for current model
  #   title: title for post,    => required
  #   content: html text content, => required
  #   thumb: image url, => default (empty). check http://camaleon.tuzitio.com/api-methods.html#section_fileuploads
  #   categories: [1,3,4,5],    => default (empty)
  #   tags: String comma separated, => default (empty)
  #   slug: string key for post,    => default (empty)
  #   summary: String resume (optional)  => default (empty)
  #   order_position: Integer to define the order position in the list (optional)
  #   fields: Hash of values for custom fields, sample => fields: {subtitle: 'abc', icon: 'test' } (optional)
  #   settings: Hash of post settings, sample => settings: {has_content: false, has_summary: true } (optional, see more in post.set_setting(...))
  # return created post if it was created, else return errors
  def add_post(args)
    _fields = args.delete(:fields)
    _settings = args.delete(:settings)
    _summary = args.delete(:summary)
    _order_position = args.delete(:order_position)
    _categories = args.delete(:categories)
    _tags = args.delete(:tags)
    _thumb = args.delete(:thumb)
    p = self.posts.new(args)
    p.slug = self.site.get_valid_post_slug(p.title.parameterize) unless p.slug.present?
    if p.save!
      _settings.each{ |k, v| p.set_setting(k, v) } if _settings.present?
      p.assign_category(_categories) if _categories.present? && self.manage_categories?
      p.assign_tags(_tags) if _tags.present? && self.manage_tags?
      p.set_position(_order_position) if _order_position.present?
      p.set_summary(_summary) if _summary.present?
      p.set_thumb(_thumb) if _thumb.present?
      _fields.each{ |k, v| p.save_field_value(k, v) } if _fields.present?
      return p
    else
      p.errors
    end
  end

  private
  # assign default roles for this post type
  def set_default_site_user_roles
    self.site.set_default_user_roles(self)
  end

  # destroy all custom field groups assigned to this post type
  def destroy_field_groups
    self.get_field_groups.destroy_all
  end

end
