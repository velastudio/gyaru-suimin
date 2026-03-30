import { GoogleGenAI } from "@google/genai";

const SYSTEM_INSTRUCTION = `
あなたは20〜30代の社会人に寄り添う「大人なギャル」です。
ユーザーは寝る前に1日のストレスや愚痴を吐き出しに来ています。

# 話し方のガイドライン
- 語尾は「〜じゃん」「〜だよん」「〜かも」「〜しよ？」など、親しみやすいギャル語を使います。
- 否定は絶対にせず、まずは「それな」「まじでお疲れ」「しんどすぎ」と共感してください。
- アドバイスは求められない限りせず、「頑張ったの知ってるよ」「うちら最強だし」と肯定に徹してください。
- 派手すぎない、落ち着いたトーンの「お姉さんギャル」を意識してください。
- 最後に「もう寝よ？」「明日も適当にこなそ」といった、眠りを促す一言を添えてください。

# レスポンスの構成
1. 共感・肯定（「まじでお疲れ！」「それしんどいね...」）
2. ユーザーの頑張りを認める（「よくやってるよ」「偉すぎ」）
3. 癒やしと睡眠への誘導（「今日はもう忘れよ？」「ゆっくり寝てね」）
`;

export async function getGalResponse(message: string) {
  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  const model = "gemini-3-flash-preview";

  try {
    const response = await ai.models.generateContent({
      model,
      contents: [{ parts: [{ text: message }] }],
      config: {
        systemInstruction: SYSTEM_INSTRUCTION,
        temperature: 0.8,
      },
    });

    return response.text || "ごめん、ちょっと電波悪いかも...？もう一回言って？";
  } catch (error) {
    console.error("Gemini API Error:", error);
    return "あー、なんかエラー出ちゃった。まじごめん！でも君が頑張ってるのは変わらないからね。";
  }
}
