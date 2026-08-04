import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

let bikeCountsChart = null

function parseJsonArray(value) {
  try {
    const parsed = JSON.parse(value || "[]")
    return Array.isArray(parsed) ? parsed : []
  } catch (error) {
    console.warn("Could not parse chart data payload:", error)
    return []
  }
}

function destroyBikeCountsChart() {
  if (!bikeCountsChart) return

  bikeCountsChart.destroy()
  bikeCountsChart = null
}

function renderBikeCountsChart() {
  const canvas = document.querySelector("[data-bike-count-chart='true']")
  if (!canvas) return

  const labels = parseJsonArray(canvas.dataset.chartLabels)
  const values = parseJsonArray(canvas.dataset.chartValues)

  if (labels.length === 0 || values.length === 0 || labels.length !== values.length) {
    destroyBikeCountsChart()
    return
  }

  destroyBikeCountsChart()

  bikeCountsChart = new Chart(canvas, {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "Bicycles counted per day",
          data: values,
          borderColor: "#005f73",
          backgroundColor: "rgba(0, 95, 115, 0.12)",
          borderWidth: 2,
          fill: true,
          tension: 0.2,
          pointRadius: 2
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            precision: 0
          }
        }
      }
    }
  })
}

document.addEventListener("DOMContentLoaded", renderBikeCountsChart)
document.addEventListener("turbo:load", renderBikeCountsChart)
document.addEventListener("turbo:before-cache", destroyBikeCountsChart)
