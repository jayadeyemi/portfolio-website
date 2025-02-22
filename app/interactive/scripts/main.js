// main.js

// Replace with your actual API Gateway URL
const apiUrl = "https://<your-api-id>.execute-api.<region>.amazonaws.com/prod/data";

// Initialize the chart using Chart.js
const ctx = document.getElementById('dataChart').getContext('2d');
let chart = new Chart(ctx, {
  type: 'bar',
  data: {
    labels: ['Value'],
    datasets: [{
      label: 'Dynamic Value',
      data: [0],
      backgroundColor: 'rgba(75, 192, 192, 0.2)',
      borderColor: 'rgba(75, 192, 192, 1)',
      borderWidth: 1
    }]
  },
  options: {
    scales: {
      y: { beginAtZero: true }
    }
  }
});

// Function to fetch JSON data from your API and update the chart
async function updateChart() {
  try {
    const response = await fetch(apiUrl);
    const result = await response.json();
    // Assuming your JSON response has a property "value"
    chart.data.datasets[0].data[0] = result.value;
    chart.update();
  } catch (error) {
    console.error('Error fetching data:', error);
  }
}

// Update the chart
updateChart();

// Node.js pseudocode
const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');
const cloudfrontDomain = process.env.CLOUDFRONT_DOMAIN;
const updatedHtml = html.replace(/<YOUR_CLOUDFRONT_DOMAIN>/g, cloudfrontDomain);
fs.writeFileSync('index.html', updatedHtml);
