<!-- 🌌 ULTRA MODERN ANIMATED BANNER -->

<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Orbitron&weight=700&size=48&duration=2500&pause=700&color=00FFF7&center=true&vCenter=true&width=1000&height=120&lines=NGROK+SSH+REMOTE+SERVER;DEPLOY+ON+RAILWAY;POWERED+BY+NOTOOKK" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/MADE%20BY-NOTOOKK-0ff?style=for-the-badge&logo=github">
  <img src="https://img.shields.io/badge/DOCKER-CONTAINER-2496ED?style=for-the-badge&logo=docker&logoColor=white">
  <img src="https://img.shields.io/badge/UBUNTU-LATEST-E95420?style=for-the-badge&logo=ubuntu&logoColor=white">
  <img src="https://img.shields.io/badge/NGROK-TUNNEL-000000?style=for-the-badge&logo=ngrok&logoColor=white">
  <img src="https://img.shields.io/badge/RAILWAY-DEPLOY-7B42BC?style=for-the-badge&logo=railway&logoColor=white">
  <img src="https://img.shields.io/github/stars/Notookk?style=social">
</p>


---

# ⚡ NGROK SSH REMOTE CONTAINER

> 🌐 Instantly turn a Docker container into a **public remote server**
> 🚀 Access it from anywhere using SSH via Ngrok
> 🧠 Built for speed, simplicity, and experimentation

---

## 👨‍💻 Developer

* **Dev:** Notookk
* **GitHub:** https://github.com/Notookk

---

## 🧬 Project Overview

This project creates a **cloud-accessible Linux environment** using:

* 🐳 Docker container
* 🐧 Ubuntu base system
* 🌐 Ngrok TCP tunnel
* 🚂 Railway deployment

### 🔥 What happens internally:

```mermaid
graph TD
A[Container Starts] --> B[Install SSH]
B --> C[Start SSH Server]
C --> D[Ngrok Tunnel Opens]
D --> E[Public TCP URL Generated]
E --> F[User Connects via SSH]
```

---

## ✨ Features

* 🌍 Public SSH access from anywhere
* ⚡ Ultra-fast deployment
* 🔐 Custom login credentials
* 🧩 Lightweight container
* 🚀 Railway ready
* 💻 Works on any device

---

## 🔑 Login Credentials

```bash
Username: morning
Password: morning123
```

---

## 🚀 Deployment (Railway)

### 1️⃣ Create Project

👉 https://railway.app

* New Project → Deploy from GitHub

---

### 2️⃣ Add Environment Variable

```env
NGROK_TOKEN=your_ngrok_token_here
```

🔗 Get token: https://dashboard.ngrok.com/get-started/your-authtoken

---

### 3️⃣ Deploy & Run

* Open logs after deployment
* Find ngrok TCP address

```bash
tcp://0.tcp.ngrok.io:XXXXX
```

---

## 🔗 SSH Connection

```bash
ssh morning@0.tcp.ngrok.io -p XXXXX
```

## 📦 Tech Stack

* 🐧 Ubuntu
* 🐳 Docker
* 🌐 Ngrok
* 🚂 Railway

---

## ⚠️ Security Notice

> 🚨 This setup is designed for testing and educational purposes only


## 💡 Use Cases

* 🧪 Testing environments
* 🤖 Bot hosting
* 🖥️ Remote access lab
* ⚙️ DevOps experiments
* 🎓 Learning containers

## 🖥️ Example Session

```bash
$ ssh morning@0.tcp.ngrok.io -p 12345

Welcome to Ubuntu

morning@container:~$
```

---

## 🌌 Visual Concept

```
[ Your PC ]
     ↓ SSH
[ Ngrok Tunnel ]
     ↓
[ Railway Container ]
     ↓
[ Ubuntu + SSH Server ]
```

---

## ⭐ Support

If you like this project:

* ⭐ Star this repo
* 🍴 Fork it
* 🚀 Share it

---

## 🧬 Credits

Made with ⚡ by **Notookk**

---

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&height=150&color=0:000000,50:00FFF7,100:000000&section=footer"/>
</p>
