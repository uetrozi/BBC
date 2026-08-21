let bikeCountsChart = null
let weatherScatterCharts = []
const MAX_LIBRARY_WAIT_ATTEMPTS = 20
const germanDateWithWeekdayFormatter = new Intl.DateTimeFormat("de-DE", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric"
})
const germanNumberFormatter = new Intl.NumberFormat("de-DE")
const germanDecimalFormatter = new Intl.NumberFormat("de-DE", {
  minimumFractionDigits: 1,
  maximumFractionDigits: 2
})

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

function destroyWeatherScatterCharts() {
  weatherScatterCharts.forEach((chart) => chart.destroy())
  weatherScatterCharts = []
}

function destroyAllCharts() {
  destroyBikeCountsChart()
  destroyWeatherScatterCharts()
}

function formatChartDateLabel(rawValue) {
  if (typeof rawValue !== "string") return rawValue

  const parsed = new Date(`${rawValue}T00:00:00Z`)
  if (Number.isNaN(parsed.valueOf())) return rawValue

  return germanDateWithWeekdayFormatter.format(parsed)
}

function setChartLibraryError(visible) {
  const message = document.querySelector("[data-chart-library-error='true']")
  if (!message) return

  message.hidden = !visible
}

function renderBikeCountsChart() {
  renderChartsWithRetry(0)
}

function renderChartsWithRetry(attempt) {
  const canvas = document.querySelector("[data-bike-count-chart='true']")
  const scatterCanvases = document.querySelectorAll("[data-weather-scatter-chart='true']")
  if (!canvas && scatterCanvases.length === 0) return

  if (typeof window.Chart === "undefined") {
    if (attempt < MAX_LIBRARY_WAIT_ATTEMPTS) {
      setTimeout(() => renderChartsWithRetry(attempt + 1), 50)
    } else {
      setChartLibraryError(true)
    }
    return
  }
  setChartLibraryError(false)

  renderBikeCountsLineChart(canvas)
  renderWeatherScatterCharts(scatterCanvases)
}

function renderBikeCountsLineChart(canvas) {
  if (!canvas) {
    destroyBikeCountsChart()
    return
  }

  const labels = parseJsonArray(canvas.dataset.chartLabels)
  const datasets = parseJsonArray(canvas.dataset.chartDatasets)

  if (labels.length === 0 || datasets.length === 0) {
    destroyBikeCountsChart()
    return
  }

  destroyBikeCountsChart()

  bikeCountsChart = new window.Chart(canvas, {
    type: "line",
    data: {
      labels,
      datasets
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        tooltip: {
          callbacks: {
            title(items) {
              const firstItem = items?.[0]
              if (!firstItem) return ""

              return formatChartDateLabel(firstItem.label)
            },
            afterBody(items) {
              const firstItem = items?.[0]
              if (!firstItem) return []

              const strikeEvent = firstItem.dataset?.strikeEvents?.[firstItem.dataIndex]
              if (!strikeEvent?.bvg_strike) return []

              return [
                `△ ${strikeEvent.label || "BVG-Warnstreik"}`,
                strikeEvent.note || "U-Bahn, Tram und die meisten Busse weitgehend außer Betrieb"
              ]
            }
          }
        }
      },
      scales: {
        x: {
          ticks: {
            callback(_value, index) {
              return formatChartDateLabel(labels[index])
            },
            maxRotation: 45,
            minRotation: 45
          }
        },
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

function renderWeatherScatterCharts(canvases) {
  destroyWeatherScatterCharts()

  canvases.forEach((canvas) => {
    const points = parseJsonArray(canvas.dataset.chartPoints)
    if (points.length === 0) return

    const isTemperatureChart = canvas.dataset.weatherScatterKind === "temperature"
    const xAxisTitle = isTemperatureChart ? "Tagesmitteltemperatur (°C)" : "Niederschlag (mm)"
    const datasetLabel = canvas.dataset.chartTitle || "Wetter und Radverkehr"
    const colors = isTemperatureChart
      ? { border: "#005f73", background: "rgba(0, 95, 115, 0.35)" }
      : { border: "#0a9396", background: "rgba(10, 147, 150, 0.35)" }

    const chart = new window.Chart(canvas, {
      type: "scatter",
      data: {
        datasets: [
          {
            label: datasetLabel,
            data: points,
            borderColor: colors.border,
            backgroundColor: colors.background,
            pointRadius(context) {
              return context.raw?.bvg_strike ? 6 : 4
            },
            pointHoverRadius(context) {
              return context.raw?.bvg_strike ? 8 : 6
            },
            pointStyle(context) {
              return context.raw?.bvg_strike ? "triangle" : "circle"
            },
            pointBorderColor(context) {
              return context.raw?.bvg_strike ? "#9b2226" : colors.border
            },
            pointBackgroundColor(context) {
              return context.raw?.bvg_strike ? "rgba(155, 34, 38, 0.45)" : colors.background
            },
            pointBorderWidth(context) {
              return context.raw?.bvg_strike ? 2 : 1
            }
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            type: "linear",
            title: {
              display: true,
              text: xAxisTitle
            }
          },
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: "Gezählte Fahrräder"
            },
            ticks: {
              precision: 0
            }
          }
        },
        plugins: {
          tooltip: {
            callbacks: {
              title(tooltipItems) {
                const firstItem = tooltipItems?.[0]
                if (!firstItem?.raw?.date) return ""

                return formatChartDateLabel(firstItem.raw.date)
              },
              label(tooltipItem) {
                const point = tooltipItem.raw || {}
                const rows = [
                  `Radzählwert: ${formatInteger(point.y)}`,
                  `Temperatur: ${formatTemperature(point.mean_temperature)}`,
                  `Niederschlag: ${formatPrecipitation(point.precipitation)}`
                ]

                if (point.bvg_strike) {
                  rows.push(`△ ${point.bvg_strike_label || "BVG-Warnstreik"}`)
                  if (point.bvg_strike_note) rows.push(point.bvg_strike_note)
                }

                return rows
              }
            }
          }
        }
      }
    })

    weatherScatterCharts.push(chart)
  })
}

function formatInteger(value) {
  if (typeof value !== "number") return String(value)

  return germanNumberFormatter.format(value)
}

function formatTemperature(value) {
  if (value === null || value === undefined) return "k. A."

  return `${germanDecimalFormatter.format(value)} °C`
}

function formatPrecipitation(value) {
  if (value === null || value === undefined) return "k. A."

  return `${germanDecimalFormatter.format(value)} mm`
}

document.addEventListener("DOMContentLoaded", renderBikeCountsChart)
document.addEventListener("turbo:load", renderBikeCountsChart)
document.addEventListener("turbo:before-cache", destroyAllCharts)
