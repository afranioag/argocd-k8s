FROM python:3

WORKDIR /app

RUN pip install Flask

COPY . .

EXPOSE 5000

CMD ["python", "./app.py"]