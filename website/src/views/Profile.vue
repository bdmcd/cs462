<template>
  <div>
    <h1>Sensor Profile</h1>
    <h5>Sensor Name</h5>
    <input v-model="name" :placeholder="name">
    <h5>Sensor Threshold</h5>
    <input v-model="threshold" :placeholder="threshold">
    <h5>Sensor Location</h5>
    <input v-model="location" :placeholder="location">
    <h5>Notification Phone Number</h5>
    <input v-model="phoneNumber" :placeholder="phoneNumber">
    <br>
    <button v-on:click="saveSettings">Save Settings</button>
  </div>
</template>

<script>
export default {
  name: "Profile",
  data: () => {
    return {
      name: null,
      threshold: null,
      location: null,
      phoneNumber: null,
    }
  },
  methods: {
    fetchData() {
      this.$http.get("c/ckn9gmg1e00f14wnsex7c7jmo/query/sensor_profile/getProfile").then((res) => {
        this.name = res.body.name;
        this.threshold = res.body.threshold;
        this.location = res.body.location;
        this.phoneNumber = res.body.number;
      })
    },
    saveSettings() {
      this.$http.post("c/ckn9gmg1e00f14wnsex7c7jmo/event-wait/sensor/profile_updated", {
        name: this.name,
        threshold: this.threshold,
        location: this.location,
        number: this.phoneNumber
      }).then(() => {
        this.fetchData();
      });
    }
  },
  mounted() {
    this.fetchData();
  },
};
</script>

<style scoped>
  h5, button {
    margin-top: 50px;
  }
</style>
