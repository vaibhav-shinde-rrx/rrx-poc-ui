import { useState } from "react";

export default function App() {
  const [text, setText] = useState("");
  const [loading, setLoading] = useState(false);
  const [output, setOutput] = useState("");

  async function send() {
    setLoading(true);
    setOutput("");
    try {
      const response = await fetch("/api/echo", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text }),
      });
      if (!response.ok) {
        setOutput(`Error: HTTP ${response.status}`);
        return;
      }
      setOutput(JSON.stringify(await response.json(), null, 2));
    } catch (err) {
      setOutput(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main style={{ fontFamily: "sans-serif", maxWidth: 480, margin: "2rem auto" }}>
      <input
        value={text}
        onChange={(event) => setText(event.target.value)}
        style={{ width: "100%", boxSizing: "border-box", padding: "0.5rem" }}
      />
      <button
        type="button"
        onClick={send}
        disabled={text.length === 0 || loading}
        style={{ marginTop: "0.75rem" }}
      >
        {loading ? "Sending..." : "Send"}
      </button>
      {output !== "" && <pre style={{ marginTop: "1rem" }}>{output}</pre>}
    </main>
  );
}
