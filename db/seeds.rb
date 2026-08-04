# frozen_string_literal: true

demo_stations = [
  {
    external_id: "DEMO-01-JAN-N",
    name: "Jannowitzbrücke Nord (Demo)",
    latitude: 52.5139322,
    longitude: 13.4178346,
    installed_at: Date.iso8601("2015-04-01")
  },
  {
    external_id: "DEMO-01-JAN-S",
    name: "Jannowitzbrücke Süd (Demo)",
    latitude: 52.5139430,
    longitude: 13.4176111,
    installed_at: Date.iso8601("2015-04-01")
  }
]

demo_stations.each do |station_attributes|
  station = CountingStation.find_or_initialize_by(external_id: station_attributes[:external_id])
  station.assign_attributes(station_attributes)
  station.save!
end

station_north = CountingStation.find_by!(external_id: "DEMO-01-JAN-N")
station_south = CountingStation.find_by!(external_id: "DEMO-01-JAN-S")

demo_counts = [
  [ station_north, "2025-05-01 08:00:00", 42 ],
  [ station_north, "2025-05-01 12:00:00", 71 ],
  [ station_north, "2025-05-02 08:00:00", 55 ],
  [ station_north, "2025-05-02 12:00:00", 84 ],
  [ station_north, "2025-05-03 08:00:00", 60 ],
  [ station_north, "2025-05-03 12:00:00", 93 ],
  [ station_south, "2025-05-01 08:00:00", 33 ],
  [ station_south, "2025-05-01 12:00:00", 58 ],
  [ station_south, "2025-05-02 08:00:00", 40 ],
  [ station_south, "2025-05-02 12:00:00", 62 ],
  [ station_south, "2025-05-03 08:00:00", 49 ],
  [ station_south, "2025-05-03 12:00:00", 74 ]
]

demo_counts.each do |station, counted_at, count|
  BikeCount.find_or_create_by!(
    counting_station: station,
    counted_at: Time.zone.parse(counted_at)
  ) do |bike_count|
    bike_count.count = count
  end
end

puts "Demo seeds applied: #{demo_stations.size} stations, #{demo_counts.size} bike count rows."
