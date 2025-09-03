import { createConsumer } from "@rails/actioncable"

let consumer = null

export function getConsumer(token) {
  if (consumer) return consumer
  const url = token ? `/cable?token=${encodeURIComponent(token)}` : "/cable"
  consumer = createConsumer(url)
  return consumer
}

