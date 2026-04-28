<template>
  <div>
    <!-- Stat Cards -->
    <n-grid :cols="4" :x-gap="16" :y-gap="16" style="margin-bottom:20px" responsive="screen" item-responsive>
      <n-gi span="4 m:2 l:1">
        <n-card size="small"><n-statistic label="本月收入" :value="stats.income" prefix="¥">
          <template #suffix><n-text type="success" style="font-size:12px">{{ stats.incomeChange }}</n-text></template>
        </n-statistic></n-card>
      </n-gi>
      <n-gi span="4 m:2 l:1">
        <n-card size="small"><n-statistic label="本月支出" :value="stats.expense" prefix="¥">
          <template #suffix><n-text type="error" style="font-size:12px">{{ stats.expenseChange }}</n-text></template>
        </n-statistic></n-card>
      </n-gi>
      <n-gi span="4 m:2 l:1">
        <n-card size="small"><n-statistic label="本月结余" :value="stats.balance" prefix="¥" /></n-card>
      </n-gi>
      <n-gi span="4 m:2 l:1">
        <n-card size="small"><n-statistic label="本月笔数" :value="stats.recordsCount" /></n-card>
      </n-gi>
    </n-grid>

    <n-grid :cols="2" :x-gap="16" :y-gap="16" responsive="screen" item-responsive>
      <!-- Monthly Trend Chart -->
      <n-gi span="2 m:1">
        <n-card title="月度收支趋势" size="small">
          <v-chart :option="barOption" style="height:300px" autoresize />
        </n-card>
      </n-gi>
      <!-- Category Pie -->
      <n-gi span="2 m:1">
        <n-card title="支出分类占比" size="small">
          <v-chart :option="pieOption" style="height:300px" autoresize />
        </n-card>
      </n-gi>
    </n-grid>

    <!-- Member Comparison -->
    <n-card title="成员消费对比" size="small" style="margin-top:16px">
      <n-grid :cols="2" :x-gap="16">
        <n-gi v-for="m in memberStats" :key="m.member">
          <n-card embedded size="small">
            <n-space justify="space-between" align="center">
              <span style="font-weight:600">{{ m.member }}</span>
              <n-text type="error" style="font-size:18px;font-weight:700">¥{{ m.expense.toFixed(2) }}</n-text>
            </n-space>
            <n-progress type="line" :percentage="m.percentage" :show-indicator="false" status="error" style="margin-top:8px" />
            <n-space justify="space-between" style="margin-top:4px;font-size:12px;color:#999">
              <span>{{ m.percentage.toFixed(0) }}% 占比</span>
              <span>{{ m.records_count }}笔</span>
            </n-space>
          </n-card>
        </n-gi>
      </n-grid>
    </n-card>

    <!-- Recent Records -->
    <n-card title="最近记录" size="small" style="margin-top:16px">
      <template #header-extra><n-button text @click="$router.push('/records')">查看全部 →</n-button></template>
      <n-data-table :columns="recentColumns" :data="recentRecords" :bordered="false" size="small" />
    </n-card>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { NTag, NText } from 'naive-ui'
import { getMonthlyStats, getStatsByMember, getRecords } from '../api'
import VChart from 'vue-echarts'
import { use } from 'echarts/core'
import { CanvasRenderer } from 'echarts/renderers'
import { BarChart, PieChart } from 'echarts/charts'
import { GridComponent, TooltipComponent, LegendComponent } from 'echarts/components'

use([CanvasRenderer, BarChart, PieChart, GridComponent, TooltipComponent, LegendComponent])

const stats = ref({ income: 0, expense: 0, balance: 0, recordsCount: 0, incomeChange: '', expenseChange: '', categories: [] })
const memberStats = ref([])
const recentRecords = ref([])

const recentColumns = [
  { title: '时间', key: 'record_time', width: 140, render: (row) => row.record_time?.slice(5, 16) },
  { title: '类型', key: 'type', width: 70, render: (row) => h(NTag, { type: row.type === 'income' ? 'success' : 'error', size: 'small' }, () => row.type === 'income' ? '收入' : '支出') },
  { title: '分类', key: 'category', width: 80, render: (row) => `${row.category?.icon || ''} ${row.category?.name || ''}` },
  { title: '金额', key: 'amount', width: 100, render: (row) => h(NText, { type: row.type === 'income' ? 'success' : 'error', strong: true }, () => `¥${row.amount.toFixed(2)}`) },
  { title: '成员', key: 'member', width: 70 },
  { title: '备注', key: 'note', ellipsis: { tooltip: true } },
  { title: '来源', key: 'source', width: 70, render: (row) => h(NTag, { type: row.source === 'ocr' ? 'info' : 'default', size: 'small' }, () => row.source === 'ocr' ? 'OCR' : '手动') },
]

import { h } from 'vue'

const barOption = computed(() => ({
  tooltip: { trigger: 'axis' },
  legend: { data: ['收入', '支出'] },
  grid: { left: 50, right: 20, bottom: 30, top: 40 },
  xAxis: { type: 'category', data: ['1月', '2月', '3月', '4月', '5月', '6月'] },
  yAxis: { type: 'value', axisLabel: { formatter: v => v >= 10000 ? (v/10000)+'w' : v } },
  series: [
    { name: '收入', type: 'bar', data: [0,0,0,0,0,0], itemStyle: { color: '#18a058' } },
    { name: '支出', type: 'bar', data: [0,0,0,0,0,0], itemStyle: { color: '#d03050' } },
  ],
}))

const pieOption = computed(() => ({
  tooltip: { trigger: 'item', formatter: '{b}: ¥{c} ({d}%)' },
  legend: { orient: 'vertical', right: 10, top: 'center' },
  series: [{
    type: 'pie', radius: ['40%', '70%'], center: ['35%', '50%'],
    label: { show: false },
    data: stats.value.categories.map(c => ({ name: c.category_name, value: c.amount })),
  }],
}))

const loadData = async () => {
  try {
    const now = new Date()
    const month = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}`

    const [monthlyRes, memberRes, recordsRes] = await Promise.all([
      getMonthlyStats({ month }),
      getStatsByMember({ month }),
      getRecords({ page_size: 5 }),
    ])

    stats.value = {
      income: monthlyRes.income || 0,
      expense: monthlyRes.expense || 0,
      balance: monthlyRes.balance || 0,
      recordsCount: monthlyRes.records_count || 0,
      incomeChange: monthlyRes.compare?.mom?.income_change || '',
      expenseChange: monthlyRes.compare?.mom?.expense_change || '',
      categories: monthlyRes.categories || [],
    }

    const totalExpense = memberRes.data?.reduce((s, m) => s + m.expense, 0) || 1
    memberStats.value = (memberRes.data || []).map(m => ({
      ...m,
      percentage: (m.expense / totalExpense) * 100,
    }))

    recentRecords.value = recordsRes.data || []
  } catch (e) {
    console.error('Dashboard load failed:', e)
  }
}

onMounted(loadData)
</script>
