FROM python:3.11
WORKDIR /code
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY . .
RUN chmod +x ./start.sh && mkdir ../logs
CMD ["./start.sh"]
