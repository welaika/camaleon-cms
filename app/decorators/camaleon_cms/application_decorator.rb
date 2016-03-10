=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::ApplicationDecorator < Draper::Decorator
  delegate_all
  @_deco_locale = nil
  include CamaleonCms::MetasDecoratorMethods

  # return the keywords for this model
  def the_keywords
    k = object.get_option("keywords", "")
    k = h.current_site.the_keywords if object.class.name != "CamaleonCms::Site" && !k.present?
    k.to_s.translate(get_locale)
  end

  def the_slug(locale = nil)
    object.slug.translate(get_locale(locale))
  end

  # return the identifier
  def the_id
    "#{object.id}"
  end

  # return created at date formatted
  def the_created_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # return updated at date formatted
  def the_updated_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # draw breadcrumb for this model
  # add_post_type: true/false to include post type link
  def the_breadcrumb(add_post_type = true)
    generate_breadcrumb(add_post_type)
    h.breadcrumb_draw
  end

  # ---------------------
  def set_decoration_locale(locale)
    @_deco_locale = locale.to_sym
  end

  # verify admin request to show the first language as the locale
  # if the request is not for frontend, then this will show current locale visited
  def get_locale(locale = nil)
    l = locale || @_deco_locale
    return l if l.present?
    (h.cama_is_admin_request? rescue false) ? h.current_site.get_languages.first : l
  end

  # internal helper
  def _calc_locale(_l)
    _l = (_l || @_deco_locale || I18n.locale).to_s
    "_#{_l}"# if _l != "en"
  end
end
