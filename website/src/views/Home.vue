<template>
  <div>
    <h2>Current Temperature: {{ temperature }} °F</h2>
    <div class="temp-data" v-for="data in temperatureData" :key="data">
      <h4 style="color:red" v-if="data.isViolation">{{data.temperature[0].temperatureF}} °F</h4>
      <h4 v-else>{{data.temperature[0].temperatureF}} °F</h4>
      <p>{{data.date}}</p>
    </div>
  </div>
</template>

<script>
import moment from 'moment'
export default {
  name: "Home",
  data: function () {
    return {
      temperatureData: [],
      violationsData: [],
    };
  },
  methods: {
    fetchTemperature() {
      this.$http
        .get("c/ckly7o89v00076sns4id33w06/query/temperature_store/temperatures")
        .then((res) => {
          this.temperatureData = res.body;
          this.temperatureData.reverse();
          this.$http
            .get(
              "c/ckly7o89v00076sns4id33w06/query/temperature_store/threshold_violations",
              {
                headers: {},
              }
            )
            .then((res) => {
              this.violationsData = res.body;
              let violationTimes = this.violationsData.map(x => x.timestamp);
              this.temperatureData = this.temperatureData.map((x) => {
                x.date = moment(String(new Date(x.timestamp))).format('MM/DD/YYYY hh:mm');
                x.isViolation = violationTimes.indexOf(x.timestamp) >= 0;
                return x;
              });
            })
            .catch((err) => {
              console.log(err);
            });
        })
        .catch((err) => {
          console.log(err);
        });
    },
    init() {
      this.fetchTemperature();
    },
  },
  computed: {
    temperature() {
      if (!this.temperatureData || this.temperatureData.length == 0) {
        return "";
      }

      return this.temperatureData[0].temperature[0].temperatureF;
    },
  },
  mounted() {
    this.init();
  },
};
</script>


<style scoped>
  .temp-data {
    margin-top: 50px;
  }
</style>