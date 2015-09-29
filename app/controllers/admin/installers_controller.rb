=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::InstallersController < CamaleonController
  skip_before_action :site_check_existence
  skip_before_action :before_actions
  skip_after_action :after_actions
  before_action :installer_verification, except: :welcome
  layout "login"

  def index
    @site ||= Site.new
    @site.slug = request.original_url.to_s.parse_domain
    render "form"
  end

  def save
    @site = Site.new(params[:site].permit(:slug, :name ))
    if @site.save
      site_after_install(@site, params[:theme])
      flash[:notice] = t('admin.sites.message.created')
      redirect_to welcome_admin_installers_url
    else
      index
    end
  end

  def welcome

  end

  def installer_verification
    redirect_to root_url unless Site.count == 0
  end
end