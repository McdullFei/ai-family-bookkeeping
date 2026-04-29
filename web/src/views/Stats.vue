<template>
  <div>
    <n-card size="small" style="margin-bottom:16px">
      <n-space align="center">
        <n-tabs v-model:value="period" type="segment" style="width:200px">
          <n-tab name="daily">日</n-tab>
          <n-tab name="weekly">周</n-tab>
          <n-tab name="monthly">月</n-tab>
        </n-tabs>
        <n-date-picker v-model:value="selectedMonth" type="month" clearable style="width:160px" />
        <n-select v-model:value="memberFilter" :options="memberOptions" placeholder="全部成员" clearable style="width:120px" />
      </n-space>
    </n-card>

    <!-- Summary Cards -->
    <n-grid :cols="3" :x-gap="16" :y-gap="16" style="margin-bottom:16px" responsive="screen" item-responsive>
      <n-gi span="3 m:1">
        <n-card size="small">
          <n-statistic label="累计支出" :value="stats.expense" prefix="¥">
            <template #footer>
              <n-text style="font-size:12px">环比 <n-text :type="stats.expenseChange?.startsWith('+') ? 'error' : 'success'">{{ stats.expenseChange }}</n-text> · 同比 <n-text :type="stats.yoyExpenseChange?.startsWith('+') ? 'error' : 'success'">{{ stats.yoyExpenseChange }}</n-text></n-text>
            </template>
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi span="3 m:1">
        <n-card size="small">
          <n-statistic label="累计收入" :value="stats.income" prefix="¥">
            <template #footer>
              <n-text style="font-size:12px">环比 <n-text :type="stats.incomeChange?.startsWith('+') ? 'error' : 'success'">{{ stats.incomeChange }}</n-text> · 同比 <n-text :type="stats.yoyIncomeChange?.startsWith('+') ? 'error' : 'success'">{{ stats.yoyIncomeChange }}</n-text></n-text>
            </template>
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi span="3 m:1">
        <n-card size="small">
          <n-statistic label="结余" :value="stats.balance" prefix="¥" />
        </n-card>
      </n-gi>
    </n-grid>

    <n-grid :cols="2" :x-gap="16" :y-gap="16" responsive="screen" item-responsive>
      <!-- Trend -->
      <n-gi span="2 m:1">
        <n-card title="支出趋势" size="small">
          <div ref="lineChartRef" style="height:280px"></div>
          <n-empty v-if="!trendData.length" description="暂无趋势数据" />
        </n-card>
      </n-gi>
      <!-- Category Ranking -->
      <n-gi span="2 m:1">
        <n-card title="支出分类排行" size="small">
          <div v-if="stats.categories && stats.categories.length">
            <div v-for="(cat, i) in stats.categories" :key="cat.category_id" style="margin-bottom:12px">
              <n-space justify="space-between" align="center" style="margin-bottom:4px">
                <span>{{ ['🥇','🥈','🥉'][i] || (i+1) }} {{ cat.category_name }}</span>
                <n-text>¥{{ Number(cat.amount).toFixed(2) }} <n-text depth="3" style="font-size:12px">{{ cat.ratio }}</n-text></n-text>
              </n-space>
              <n-progress type="line" :percentage="parseFloat(cat.ratio)" :show-indicator="false" :color="categoryColors[i % categoryColors.length]" />
            </div>
          </div>
          <n-empty v-else description="暂无分类数据" />
        </n-card>
      </n-gi>
    </n-grid>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, nextTick } from 'vue'
import { getMonthlyStats, getWeeklyStats, getDailyStats, getStatsByMember, getMembers } from '../api'

const period = ref('monthly')
const selectedMonth = ref(Date.now())
const memberFilter = ref(null)
const memberOptions = ref([])
const lineChartRef = ref(null)
const trendData = ref([])

const stats = ref({
  income: 0, expense: 0, balance: 0,
  incomeChange: '', expenseChange: '',
  yoyIncomeChange: '', yoyExpenseChange: '',
  categories: []
})
const categoryColors = ['#d03050', '#2080f0', '#f0a020', '#8a2be2', '#18a058', '#999']

const loadData = async () => {
  try {
    const d = new Date(selectedMonth.value)
    const month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    const params = { month }
    if (memberFilter.value) params.member = memberFilter.value

    let res
    if (period.value === 'daily') {
      res = await getDailyStats(params)
    } else if (period.value === 'weekly') {
      res = await getWeeklyStats(params)
    } else {
      res = await getMonthlyStats(params)
    }

    stats.value = {
      income: res.income || 0,
      expense: res.expense || 0,
      balance: res.balance || 0,
      incomeChange: res.compare?.mom?.income_change || '0%',
      expenseChange: res.compare?.mom?.expense_change || '0%',
      yoyIncomeChange: res.compare?.yoy?.income_change || 'N/A',
      yoyExpenseChange: res.compare?.yoy?.expense_change || 'N/A',
      categories: res.categories || [],
    }
    trendData.value = res.trend || []
  } catch (e) {
    console.error('Stats load failed:', e)
  }
}

onMounted(async () => {
  try {
    const memRes = await getMembers()
    memberOptions.value = (memRes.data || []).map(m => ({ label: m.name, value: m.name }))
  } catch (e) { /* ignore */ }
  loadData()
})

watch([selectedMonth, memberFilter, period], loadData)
</script>
