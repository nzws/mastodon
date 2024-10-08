# frozen_string_literal: true

module ThumbnailHelper
  def thumbnail_url
    full_asset_url(instance_presenter.thumbnail&.file&.url || asset_pack_path('media/images/preview.png'))
  end

  private

  def instance_presenter
    @instance_presenter ||= InstancePresenter.new
  end
end
