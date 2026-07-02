import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  "https://hakhmatvjvjinkfeilbv.supabase.co", 
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhha2htYXR2anZqaW5rZmVpbGJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMTM5NDAsImV4cCI6MjA5NzY4OTk0MH0.sxbTw9-dvNTXh-Clog9BAAf6HjgNETNRki_vKe5vBCE"
);

async function run() {
  const { data, error } = await supabase.auth.getUser("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhha2htYXR2anZqaW5rZmVpbGJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMTM5NDAsImV4cCI6MjA5NzY4OTk0MH0.sxbTw9-dvNTXh-Clog9BAAf6HjgNETNRki_vKe5vBCE");
  console.log(error?.name, error?.message);
}
run();
