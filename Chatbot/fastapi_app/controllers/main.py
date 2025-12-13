from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import uvicorn

# ======================
# CONFIG
# ======================
BASE_MODEL = "/home/vophilong/Documents/DACN/ChatBot/Qwen2.5-1.5B-Instruct/"
LORA_PATH  = "/home/vophilong/Documents/DACN/ChatBot/complete/qwen2_5_1b_emotion/"

# ======================
# LOAD MODEL
# ======================
print("Đang tải model...")

tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL, trust_remote_code=True)

model = AutoModelForCausalLM.from_pretrained(
    BASE_MODEL,
    torch_dtype=torch.float16,
    device_map="auto",
    trust_remote_code=True
)

print("Đang tải LoRA...")
model.load_adapter(LORA_PATH)
model.eval()

print("SERVER SẴN SÀNG!")

# ======================
# FASTAPI
# ======================
app = FastAPI(title="Emotion AI API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Cho Flutter truy cập
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ======================
# REQUEST BODY
# ======================
class EmotionRequest(BaseModel):
    emotion: str
    confidence: float | None = None
# ======================
# API FOR FLUTTER
# ======================
@app.post("/generate")
def generate(req: EmotionRequest):
    confidence_text = (
        f"{int(req.confidence * 100)}%"
        if req.confidence is not None
        else "không xác định"
    )

    prompt = (
        f"Cảm xúc người dùng: {req.emotion}\n"
        f"Độ tin cậy: {confidence_text}\n"
        "Vai trò: Bạn là trợ lý tâm lý AI.\n"
        "Hãy phản hồi ngắn gọn, đồng cảm, tự nhiên.\n"
        "Chỉ 1–2 câu, tiếng Việt, kết thúc bằng dấu chấm.\n"
        "Phản hồi:"
    )

    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_new_tokens=80,
            repetition_penalty=1.25,
            temperature=0.7,
            top_p=0.9,
            top_k=50,
            pad_token_id=tokenizer.eos_token_id
        )

    text = tokenizer.decode(output[0], skip_special_tokens=True)
    response_text = text.replace(prompt, "").strip()

    return {
        "emotion": req.emotion,
        "response": response_text
    }

# ======================
# RUN SERVER FOR MOBILE
# ======================
if __name__ == "__main__":
    # ⚠️ BẮT BUỘC 0.0.0.0 ĐỂ ĐIỆN THOẠI KẾT NỐI
    uvicorn.run(app, host="0.0.0.0", port=8000)
