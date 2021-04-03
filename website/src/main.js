import Vue from 'vue'
import App from './App.vue'
import router from './router'
import vueResource from 'vue-resource'

Vue.config.productionTip = false
Vue.use(vueResource)

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')
