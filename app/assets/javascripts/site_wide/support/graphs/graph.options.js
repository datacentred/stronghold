var StrongholdGraphOptions = {
  defaultOptions: {
    credits: {
      enabled: false
    },
    exporting: {
      enabled: false
    }
  },
  semiPieChartOptions: function(seriesData) {
    return $.extend(true, {
      chart: {
        plotBackgroundColor: null,
        plotBorderWidth: 0,
        plotShadow: false
      },
      title: {
        text: ''
      },
      tooltip: {
        pointFormat: ''
      },
      plotOptions: {
        pie: {
          dataLabels: {
            enabled: true,
            distance: -50,
            style: {
              fontWeight: 'bold',
              color: 'white',
              textShadow: '0px 1px 2px black',
              fontFamily: "'Signika', arial, sans-serif"
            }
          },
          startAngle: -90,
          endAngle: 90,
          center: ['50%', '75%']
        }
      },
      series: [{
        showInLegend: false,
        type: 'pie',
        name: '',
        innerSize: '50%',
        data: seriesData
      }]
    }, StrongholdGraphOptions.defaultOptions);
  },
  pieChartOptions: function(unit, seriesData) {
    return $.extend(true, {
      chart: {
        plotBackgroundColor: null,
        plotBorderWidth: null,
        plotShadow: false,
        type: 'pie'
      },
      title: {
        text: ''
      },
      tooltip: {
        pointFormat: '<b>{point.y:.0f}</b> ' + unit
      },
      plotOptions: {
        pie: {
          allowPointSelect: true,
          cursor: 'pointer',
          dataLabels: {
            enabled: true,
            format: '<b>{point.name}</b>: {point.y:.0f}',
            style: {
                color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
            }
          }
        }
      },
      series: [{
        name: '',
        data: seriesData
      }],
      series: [{
        colorByPoint: true,
        data: seriesData
      }]
    }, StrongholdGraphOptions.defaultOptions);
  }
}
