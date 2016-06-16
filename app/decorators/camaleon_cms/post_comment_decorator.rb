=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::PostCommentDecorator < Draper::Decorator
  delegate_all

  # return created at date formatted
  def the_created_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # return owner of this comment
  def the_user
    object.user.decorate
  end
  alias_method :the_author, :the_user

  def the_post
    object.post.decorate
  end

  def the_content
    object.content
  end

  def the_answers
    object.children.approveds
  end

  def the_author_name
    object.author.presence || object.user.full_name
  end

  def the_author_email
    object.author_email.presence || object.user.email
  end

  def the_author_url
    object.author_url.presence || (object.user.username == 'anonymous' ? '' : object.user.decorate.the_url)
  end

end
