class DisableThenEnablePostgisExtension < ActiveRecord::Migration[6.1]
  def change
    disable_extension "postgis"
    enable_extension "postgis"
  end
end
