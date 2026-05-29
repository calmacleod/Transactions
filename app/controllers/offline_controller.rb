class OfflineController < ApplicationController
  def show
    render inertia: {
      snapshot_path: offline_snapshot_path(format: :json)
    }
  end

  def snapshot
    render json: OfflineSnapshot.new(user: current_user).to_h
  end
end
