# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời bên dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Vu Huy Do  Mã học viên: 2A202602555

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu cấu hình mặc định là `"changeme"`, khi deploy lên server thật (production), nếu lập trình viên hoặc kỹ sư DevOps sơ suất quên khai báo biến `AGENT_API_KEY` trong dashboard, ứng dụng vẫn sẽ khởi động bình thường và báo trạng thái healthy. Tuy nhiên, khóa bảo vệ endpoint `/ask` lúc này lại là `"changeme"` — một chuỗi mặc định ai cũng đoán được hoặc đã lộ trong mã nguồn. Bất kỳ ai trên Internet cũng có thể gửi request nặc danh, khai thác API bot, spam mô hình ngôn ngữ lớn và làm cạn kiệt ngân sách hàng nghìn USD chỉ trong thời gian ngắn.

Với cơ chế "Fail Fast", vì thiếu `agent_api_key`, Pydantic Settings lập tức raise `ValidationError` khiến container crash ngay từ giây đầu tiên lúc khởi động. Nền tảng cloud (Render/Kubernetes) sẽ nhận diện tiến trình không khởi động được và ngăn chặn rollout bản build lỗi lên môi trường thực tế, cứu toàn bộ hệ thống khỏi thảm họa bảo mật và thiệt hại tài chính.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
```json
{"timestamp": "2026-09-29T04:37:38.125000Z", "level": "info", "event": "ask_completed", "user_id": "sv-test", "cost_usd": 0.00002145, "history_length": 0, "status_code": 200}
```

Hai việc làm được với dòng log có cấu trúc (JSON) mà lệnh `print("đã trả lời xong")` không thể làm được:
1. **Lọc, truy vấn và dựng Dashboard/Cảnh báo tự động trên hệ thống quản lý log (như Datadog, ELK Stack, Grafana Loki)**: Vì log là JSON với các trường dữ liệu rõ ràng (`user_id`, `cost_usd`, `status_code`), các công cụ có thể tự động bóc tách (parse) mà không cần regex. Ta có thể viết truy vấn chính xác như `event="ask_completed" AND cost_usd > 0.01` hoặc vẽ biểu đồ tổng chi phí theo thời gian thực của từng user.
2. **Kiểm toán (Auditing) và đối chiếu chi phí chính xác**: Trường `timestamp` chuẩn ISO 8601 UTC kết hợp định danh `user_id` và số tiền `cost_usd` cho phép truy vết lịch sử sử dụng chi tiết của từng người dùng khi có khiếu nại hoặc nghi vấn tấn công. Trong khi đó, `print("đã trả lời xong")` hoàn toàn không có thông tin ngữ cảnh nào (ai gọi, lúc nào, tốn bao nhiêu).

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~520 MB |
| Multi-stage | 272 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~250 MB) bao gồm:
- Toàn bộ bộ nhớ cache khi tải package của pip (`~/.cache/pip`).
- Các công cụ build, trình biên dịch C/C++ (`gcc`, `make`, `build-essential`) và các file headers phát triển (`python3-dev`) cần thiết để biên dịch các package native nhưng không cần thiết khi chạy ứng dụng.
- Các file tài liệu, test suites và file tạm trung gian phát sinh trong quá trình build package.
- Ở kiến trúc multi-stage, stage `builder` chịu trách nhiệm cài đặt và biên dịch thư viện vào thư mục `/root/.local`. Stage `runner` chỉ sao chép đúng thư mục thư viện đã hoàn chỉnh sang người dùng không đặc quyền `/home/appuser/.local`, loại bỏ hoàn toàn các overhead thừa thãi.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- **Với Dockerfile hiện tại** (tách `COPY requirements.txt .` $\rightarrow$ `RUN pip install` $\rightarrow$ `COPY app/ app/`):
  - Khi sửa một ký tự trong `app/main.py`, file `requirements.txt` không thay đổi nội dung (checksum không đổi). Do đó, Docker sử dụng lại toàn bộ cache từ base image, cài đặt thư viện hệ thống cho đến bước cài đặt dependencies `RUN pip install`.
  - Chỉ có layer `COPY app/ app/` và các lệnh phía sau (đổi quyền thư mục, gán USER, CMD) là phải chạy lại. Toàn bộ quá trình build lại chỉ mất chưa đầy 1 giây.
- **Nếu đặt `COPY . .` lên trước `RUN pip install`**:
  - Bất kỳ khi nào sửa code trong `app/main.py`, layer `COPY . .` sẽ bị vô hiệu hóa cache (cache invalidated).
  - Khi một layer bị mất cache, tất cả các layer kế tiếp sau nó đều phải chạy lại. Kết quả là lệnh `RUN pip install` sẽ bị kích hoạt chạy lại từ đầu, Docker phải tải và cài đặt lại toàn bộ thư viện Python mỗi lần build. Việc này làm thời gian build tăng từ 1 giây lên hàng chục giây đến vài phút và lãng phí băng thông mạng.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- **Chuỗi sự kiện tấn công (Container Escape & Privilege Escalation)**:
  1. Ứng dụng Python chứa lỗ hổng RCE (Remote Code Execution, ví dụ do deserialization không an toàn, command injection, hoặc thư viện bên thứ ba bị zero-day).
  2. Kẻ tấn công gửi payload khai thác thành công và chiếm được quyền thực thi shell bên trong container.
  3. Mặc định container chạy dưới quyền `root` (UID 0). Do container dùng chung nhân Linux kernel với máy host, tiến trình của kẻ tấn công trong container cũng có UID 0 trên kernel host.
  4. Kẻ tấn công lợi dụng đặc quyền root này để khai thác các cấu hình hở (như Docker socket mounted `/var/run/docker.sock`, privileged mode, kernel vulnerability, hoặc mount host filesystem) để thoát khỏi container (Container Escape) và nắm toàn quyền root trên máy host thật.
- **Lệnh `USER` cắt đứt chuỗi tại đâu**:
  - Lệnh `USER appuser` (UID 10001) cắt đứt chuỗi ngay tại **Bước 3**. Kẻ tấn công dù chiếm được quyền thực thi trong container thì cũng chỉ mang quyền hạn của một người dùng thông thường (`appuser`), không có quyền root (`sudo` hay UID 0). Kẻ tấn công không thể ghi vào các file nhạy cảm của hệ điều hành, không thể truy cập socket docker hay can thiệp vào các tài nguyên của host kernel.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- **Con số tối đa**: **20 requests**.
- **Cách đạt được**:
  - Với thuật toán fixed window đếm theo phút đồng hồ (reset vào giây 00):
    - Ở phút thứ $T$, vào đúng giây thứ 59, người dùng gửi dồn dập 10 requests. Vì trong phút $T$ chưa có request nào nên cả 10 requests này đều được hệ thống chấp nhận.
    - Đúng 1 giây sau, đồng hồ chuyển sang phút $T+1$ (giây 00). Bộ đếm của phút $T+1$ lập tức được reset về 0. Người dùng gửi tiếp 10 requests nữa ngay trong giây 00 này. Hệ thống tính 10 request này thuộc về phút $T+1$ nên tiếp tục cho qua.
  - Kết quả: Trong khoảng thời gian chỉ vỏn vẹn **2 giây liên tiếp** (từ giây 59 sang giây 00), người dùng đã gửi thành công **20 requests** — gấp đôi hạn mức 10 req/phút, tạo ra xung đột tải (traffic spike) làm nghẽn dịch vụ.
  - Sliding window giải quyết triệt để vấn đề này vì nó luôn tính khoảng thời gian 60 giây động tính từ thời điểm request hiện tại lùi về quá khứ, đảm bảo không bao giờ có quá 10 request trong bất kỳ khoảng 60 giây nào.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- **Sự khác nhau cơ bản**:
  - **Rate Limit**: Bảo vệ **hạ tầng & tính sẵn sàng tức thời** (chống nghẽn mạng, chống DoS/DDoS server). Đo lường theo **tần suất gọi API trong một khung thời gian ngắn** (ví dụ: 10 request / 60 giây).
  - **Cost Guard**: Bảo vệ **tài chính & ngân sách dài hạn** (chống thủng ngân sách chi phí token/LLM). Đo lường theo **tổng số tiền chi tiêu tích lũy trong chu kỳ tài chính dài** (ví dụ: $10.0 / tháng).
- **Tình huống Rate Limit cho qua nhưng Cost Guard chặn**:
  - Người dùng chỉ gửi đúng 1 request duy nhất trong ngày (rất xa giới hạn 10 req/phút). Tuy nhiên, trong tháng đó người dùng đã tích lũy chi phí đạt $9.9999 trên hạn mức $10.0/tháng. Khi request này đến, chi phí ước tính vượt quá $10.0 $\rightarrow$ Rate limit cho qua vì tần suất rất thấp, nhưng Cost Guard chặn và trả về HTTP 402 Payment Required.
- **Tình huống Cost Guard cho qua nhưng Rate Limit chặn**:
  - Vào ngày đầu tiên của tháng mới, ngân sách của người dùng còn nguyên $10.0. Người dùng chạy script gửi dồn 15 câu hỏi ngắn trong vòng 3 giây. Tổng chi phí của 15 câu hỏi này chỉ khoảng $0.0003 (chưa thấm vào đâu so với $10.0) $\rightarrow$ Cost Guard cho qua, nhưng Rate Limit lập tức chặn từ request thứ 11 và trả về HTTP 429 Too Many Requests để bảo vệ tài nguyên máy chủ.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

- **Thứ tự sự kiện xảy ra**:
  1. Redis bị gián đoạn mạng hoặc quá tải trong 30 giây.
  2. Bộ điều phối (Docker Swarm/Kubernetes/Render) gửi probe định kỳ kiểm tra liveness tới endpoint duy nhất này. Vì endpoint kiểm tra Redis và thấy Redis tạch, nó trả về mã lỗi HTTP 500 hoặc 503.
  3. Bộ điều phối lầm tưởng rằng tiến trình chính của ứng dụng Python/FastAPI bên trong container đã bị chết/treo cứng.
  4. Bộ điều phối lập tức kích hoạt cơ chế tự phục hồi: **kill và restart toàn bộ cả 3 container** ứng dụng.
  5. Trong khi Redis vẫn chưa hồi phục, các container mới khởi động lại tiếp tục kiểm tra Redis $\rightarrow$ lại fail $\rightarrow$ lại bị kill và restart liên tục (rơi vào vòng lặp tử thần **CrashLoopBackOff**).
  6. Toàn bộ cụm dịch vụ bị sập hoàn toàn, các kết nối đang xử lý bị ngắt ngang, CPU máy chủ bị chiếm dụng bởi việc khởi động lại container liên tục.
  7. **Giải pháp chuẩn**: Tách riêng `/health` (chỉ kiểm tra app process có còn thở hay không để quyết định restart) và `/ready` (kiểm tra dependencies như Redis để quyết định có chuyển traffic vào hay tạm dừng phân phối). Khi Redis mất kết nối 30s, `/ready` fail để load balancer ngưng gửi request, nhưng `/health` vẫn 200 OK để container không bị kill vô cớ.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- **Nếu lưu trong dict Python cục bộ (Stateful in-memory)**:
  - Khi scale lên 3 container (`agent=3`), load balancer (như Nginx hay Docker DNS round-robin) sẽ phân phối các request kế tiếp nhau lần lượt vào các container khác nhau.
  - Do mỗi container là một tiến trình độc lập với vùng nhớ RAM riêng, dict Python ở container A không hề biết những gì xảy ra ở container B hay C.
  - Kết quả là `history_length` sẽ **thay đổi thất thường và không liên tục**:
    - Lần gọi 1 (vào Container 1): `history_length` = 0.
    - Lần gọi 2 (vào Container 2): `history_length` = 0 (vì Container 2 chưa từng gặp user này).
    - Lần gọi 3 (vào Container 3): `history_length` = 0.
    - Lần gọi 4 (quay lại Container 1): `history_length` = 1.
  - Người dùng sẽ thấy bot bị "mất trí nhớ từng lúc" tùy thuộc request rơi trúng container nào.
- **Khi lưu trong Redis tập trung (Stateless backend)**:
  - Mọi container đều truy cập chung một key `history:{user_id}` trên Redis. Bất kể container nào xử lý, lịch sử hội thoại luôn được đọc và ghi nhất quán, `history_length` tăng đều đặn 0 $\rightarrow$ 1 $\rightarrow$ 2 $\rightarrow$ 3...

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Lỗi gặp phải**: Lỗi kết nối Redis khi deploy song song Web Service và Redis trên Render qua Blueprint: ban đầu ứng dụng không thể kết nối tới Redis nếu để mặc định `REDIS_URL=redis://localhost:6379`.
- **Thông báo lỗi**: Khi kiểm tra endpoint readiness, service trả về HTTP 503 hoặc log trên Render hiển thị: `redis.exceptions.ConnectionError: Error 111 connecting to localhost:6379. Connection refused.`
- **Cách tìm ra nguyên nhân**: Mở tab Logs của dịch vụ `day12-agent` trên Render Dashboard. Nhận thấy container của Web Service chạy trong mạng cô lập (isolated container) và không thể truy cập Redis thông qua `localhost` như khi chạy máy cá nhân.
- **Cách sửa**:
  - Sử dụng tính năng Blueprint liên kết dịch vụ trong file `render.yaml`:
    ```yaml
    - key: REDIS_URL
      fromService:
        name: day12-redis
        type: redis
        property: connectionString
    ```
  - Thuộc tính này chỉ định Render tự động truyền chuỗi kết nối mạng nội bộ (`red-...:6379`) của instance `day12-redis` sang `day12-agent`.
  - Sau khi apply, kiểm tra lại bằng lệnh `curl -i https://day12-agent-8j4y.onrender.com/ready` trả về ngay HTTP 200 `{"status":"ready","redis":true}`.

