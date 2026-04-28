<template>
  <div>
    <!-- Expense Categories -->
    <n-card size="small" style="margin-bottom:16px">
      <template #header>
        <n-space justify="space-between" align="center" style="width:100%">
          <span>支出分类</span>
          <n-button type="primary" size="small" @click="openCreate('expense')">+ 新增分类</n-button>
        </n-space>
      </template>
      <n-grid :cols="5" :x-gap="12" :y-gap="12" responsive="screen" item-responsive>
        <n-gi v-for="cat in expenseCategories" :key="cat.id" span="5 m:2 l:1">
          <n-card embedded size="small" hoverable>
            <n-space align="center" justify="space-between">
              <n-space align="center">
                <span style="font-size:24px">{{ cat.icon }}</span>
                <div>
                  <div style="font-weight:500">{{ cat.name }}</div>
                  <div style="font-size:11px;color:#999">支出</div>
                </div>
              </n-space>
              <n-button text size="small" @click="openEdit(cat)">编辑</n-button>
            </n-space>
          </n-card>
        </n-gi>
      </n-grid>
    </n-card>

    <!-- Income Categories -->
    <n-card size="small">
      <template #header>
        <n-space justify="space-between" align="center" style="width:100%">
          <span>收入分类</span>
          <n-button type="primary" size="small" @click="openCreate('income')">+ 新增分类</n-button>
        </n-space>
      </template>
      <n-grid :cols="5" :x-gap="12" :y-gap="12" responsive="screen" item-responsive>
        <n-gi v-for="cat in incomeCategories" :key="cat.id" span="5 m:2 l:1">
          <n-card embedded size="small" hoverable>
            <n-space align="center" justify="space-between">
              <n-space align="center">
                <span style="font-size:24px">{{ cat.icon }}</span>
                <div>
                  <div style="font-weight:500">{{ cat.name }}</div>
                  <div style="font-size:11px;color:#999">收入</div>
                </div>
              </n-space>
              <n-button text size="small" @click="openEdit(cat)">编辑</n-button>
            </n-space>
          </n-card>
        </n-gi>
      </n-grid>
    </n-card>

    <!-- Create/Edit Modal -->
    <n-modal v-model:show="modalVisible" preset="dialog" :title="isEdit ? '编辑分类' : '新增分类'"
      positive-text="保存" negative-text="取消" @positive-click="handleSave">
      <n-form :model="formData" label-placement="left" label-width="80">
        <n-form-item label="名称"><n-input v-model:value="formData.name" placeholder="分类名称" /></n-form-item>
        <n-form-item label="图标">
          <n-input v-model:value="formData.icon" placeholder="emoji图标" style="width:80px" />
        </n-form-item>
        <n-form-item label="类型">
          <n-radio-group v-model:value="formData.type" :disabled="isEdit">
            <n-radio value="expense">支出</n-radio>
            <n-radio value="income">收入</n-radio>
          </n-radio-group>
        </n-form-item>
        <n-form-item label="排序"><n-input-number v-model:value="formData.sort_order" /></n-form-item>
      </n-form>
    </n-modal>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useMessage, useDialog } from 'naive-ui'
import { getCategories, createCategory, updateCategory, deleteCategory } from '../api'

const message = useMessage()
const dialog = useDialog()
const categories = ref([])
const modalVisible = ref(false)
const isEdit = ref(false)
const formData = ref({ name: '', icon: '', type: 'expense', sort_order: 0 })

const expenseCategories = computed(() => categories.value.filter(c => c.type === 'expense'))
const incomeCategories = computed(() => categories.value.filter(c => c.type === 'income'))

const loadData = async () => {
  try {
    const res = await getCategories()
    categories.value = res.data || []
  } catch (e) {
    message.error('加载失败')
  }
}

const openCreate = (type) => {
  isEdit.value = false
  formData.value = { name: '', icon: '', type, sort_order: 0 }
  modalVisible.value = true
}

const openEdit = (cat) => {
  isEdit.value = true
  formData.value = { ...cat }
  modalVisible.value = true
}

const handleSave = async () => {
  try {
    if (isEdit.value) {
      await updateCategory(formData.value.id, formData.value)
    } else {
      await createCategory(formData.value)
    }
    message.success('保存成功')
    loadData()
  } catch (e) {
    message.error(e.error || '保存失败')
  }
}
</script>
