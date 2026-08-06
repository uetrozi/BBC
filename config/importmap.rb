# Pin npm packages by running ./bin/importmap

pin "application"
pin_all_from "app/javascript/charts", under: "charts"
pin "chart.js" # @4.5.1
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "chart.js/auto", to: "chart.js--auto.js" # @4.5.1
