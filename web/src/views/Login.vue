<template>
  <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#1f2937,#374151,#1f2937)">
    <n-card style="width:380px;box-shadow:0 20px 60px rgba(0,0,0,.3)" :bordered="false">
      <div style="text-align:center;margin-bottom:24px">
        <h2 style="margin:0 0 8px">🏠 家庭账本</h2>
        <p style="color:#999;font-size:13px">管理后台登录</p>
      </div>
      <n-form ref="formRef" :model="form" :rules="rules" @keyup.enter="handleLogin">
        <n-form-item path="username" label="用户名">
          <n-input v-model:value="form.username" placeholder="请输入用户名" />
        </n-form-item>
        <n-form-item path="password" label="密码">
          <n-input v-model:value="form.password" type="password" show-password-on="click" placeholder="请输入密码" />
        </n-form-item>
        <n-button type="primary" block :loading="loading" @click="handleLogin" style="margin-top:8px">登 录</n-button>
      </n-form>
    </n-card>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useMessage } from 'naive-ui'
import { login } from '../api'

const router = useRouter()
const message = useMessage()
const form = ref({ username: '', password: '' })
const loading = ref(false)
const rules = {
  username: { required: true, message: '请输入用户名', trigger: 'blur' },
  password: { required: true, message: '请输入密码', trigger: 'blur' },
}

const handleLogin = async () => {
  loading.value = true
  try {
    const res = await login(form.value)
    localStorage.setItem('token', res.token)
    message.success('登录成功')
    router.push('/dashboard')
  } catch (e) {
    message.error(e.error || '登录失败')
  } finally {
    loading.value = false
  }
}
</script>
