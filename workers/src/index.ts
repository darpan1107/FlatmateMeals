export interface Env {
  TELEGRAM_BOT_TOKEN: string;
  TELEGRAM_GROUP_ID: string;
  TURSO_URL: string;
  TURSO_AUTH_TOKEN: string;
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === "/api/telegram/webhook" && req.method === "POST") {
      const update = await req.json();
      console.log("telegram update", update);
      // TODO: route poll_answer / message updates
      return new Response("ok");
    }
    if (url.pathname === "/health") {
      return Response.json({ ok: true });
    }
    return new Response("not found", { status: 404 });
  },

  async scheduled(event: ScheduledEvent, env: Env): Promise<void> {
    const hour = new Date(event.scheduledTime).getUTCHours();
    console.log("cron fired at UTC hour", hour);
    // TODO: 10:00 UTC => generate + send polls
    // TODO: 15:30 UTC => close + announce
  },
};

