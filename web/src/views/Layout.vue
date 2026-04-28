<template>
  <n-layout has-sider style="height:100vh">
    <n-layout-sider bordered :width="220" :native-scrollbar="false" content-style="padding:0">
      <div style="padding:20px 16px 12px;border-bottom:1px solid rgba(255,255,255,.1)">
        <h2 style="margin:0;color:#fff;font-size:18px">🏠 家庭账本</h2>
        <p style="margin:4px 0 0;color:rgba(255,255,255,.45);font-size:12px">AI-Powered Bookkeeping</p>
      </div>
      <n-menu :options="menuOptions" :value="activeKey" @update:value="handleMenu" :inverted="true" />
    </n-layout-sider>
    <n-layout>
      <n-layout-header bordered style="padding:12px 24px;display:flex;align-items:center;justify-content:space-between;background:#fff;position:sticky;top:0;z-index:50">
        <div>
          <h3 style="margin:0;font-size:16px">{{ currentTitle }}</h3>
        </div>
        <n-button text @click="handleLogout" style="font-size:13px">退出登录</n-button>
      </n-layout-header>
      <n-layout-content content-style="padding:20px 24px" style="background:#f5f7f9">
        <router-view />
      </n-layout-content>
    </n-layout>
  </n-layout>
</template>

<script setup>
import { computed, h } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { NIcon } from 'naive-ui'
import {
  HomeOutline,
  ListOutline,
  StatsChartOutline,
  PricetagsOutline,
} from '@vicons/ionicons5'

const router = useRouter()
const route = useRoute()

const activeKey = computed(() => route.path.slice(1) || 'dashboard')
const currentTitle = computed(() => route.meta.title || '')

const renderIcon = (icon) => () => h(NIcon, null, { default: () => h(icon) })

const menuOptions = [
  { label: '概览', type: 'group', key: 'g1' },
  { label: '仪表盘', key: 'dashboard', icon: renderIcon(HomeOutline) },
  { label: '数据', type: 'group', key: 'g2' },
  { label: '收支明细', key: 'records', icon: renderIcon(ListOutline) },
  { label: '统计报表', key: 'stats', icon: renderIcon(StatsChartOutline) },
  { label: '管理', type: 'group', key: 'g3' },
  { label: '分类管理', key: 'categories', icon: renderIcon(PricetagsOutline) },
]

const handleMenu = (key) => {
  router.push(`/${key}`)
}

const handleLogout = () => {
  localStorage.removeItem('token')
  router.push('/login')
}
</script>
