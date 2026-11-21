# Студент: Яровий Михайло, група КН-42
# Офіційний образ Node.js з поточною LTS-версією
FROM node:lts

# Робоча директорія застосунку всередині контейнера
WORKDIR /usr/src/app

# Спочатку лише маніфести залежностей: шар npm install кешується,
# доки не зміняться package.json / package-lock.json
COPY package*.json ./
RUN npm install

# Потім решта коду (зміни в index.js не перевстановлюють node_modules)
COPY . .

EXPOSE 3000
CMD ["npm", "start"]
