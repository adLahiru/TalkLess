# Qt6 C++ Integration Guide

## Backend API Information

**Production URL**: `https://talkless-backend.vercel.app`

**Base API Endpoint**: `https://talkless-backend.vercel.app/api`

---

## API Endpoints Reference

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/api/health` | Health check | No |
| POST | `/api/auth/signup` | Register new user | No |
| POST | `/api/auth/login` | Authenticate user | No |
| GET | `/api/auth/me` | Get current user | Yes |
| POST | `/api/auth/logout` | Logout (client-side) | No |

---

## Qt6 C++ Implementation

### 1. Project Setup

Add to your `.pro` file:
```qmake
QT += network
```

Or for CMake (`CMakeLists.txt`):
```cmake
find_package(Qt6 REQUIRED COMPONENTS Network)
target_link_libraries(your_app PRIVATE Qt6::Network)
```

---

### 2. API Client Header (`ApiClient.h`)

```cpp
#ifndef APICLIENT_H
#define APICLIENT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>

class ApiClient : public QObject
{
    Q_OBJECT

public:
    explicit ApiClient(QObject *parent = nullptr);
    
    // API Methods
    void signup(const QString &email, const QString &password, 
                const QString &firstName, const QString &lastName,
                const QString &phoneNumber = QString());
    void login(const QString &email, const QString &password);
    void getCurrentUser();
    void logout();
    
    // Token Management
    void setAuthToken(const QString &token);
    QString getAuthToken() const;
    void clearAuthToken();

signals:
    void signupSuccess(const QJsonObject &userData, const QString &token);
    void signupError(const QString &errorMessage);
    
    void loginSuccess(const QJsonObject &userData, const QString &token);
    void loginError(const QString &errorMessage);
    
    void userDataReceived(const QJsonObject &userData);
    void userDataError(const QString &errorMessage);
    
    void logoutSuccess();

private slots:
    void onNetworkReply(QNetworkReply *reply);

private:
    QNetworkAccessManager *m_networkManager;
    QString m_baseUrl;
    QString m_authToken;
    
    void sendPostRequest(const QString &endpoint, const QJsonObject &data, 
                        const QString &requestType);
    void sendGetRequest(const QString &endpoint, const QString &requestType);
    QNetworkRequest createRequest(const QString &endpoint, bool requiresAuth = false);
};

#endif // APICLIENT_H
```

---

### 3. API Client Implementation (`ApiClient.cpp`)

```cpp
#include "ApiClient.h"
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrlQuery>

ApiClient::ApiClient(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_baseUrl("https://talkless-backend.vercel.app/api")
{
    connect(m_networkManager, &QNetworkAccessManager::finished,
            this, &ApiClient::onNetworkReply);
}

void ApiClient::signup(const QString &email, const QString &password,
                       const QString &firstName, const QString &lastName,
                       const QString &phoneNumber)
{
    QJsonObject data;
    data["email"] = email;
    data["password"] = password;
    data["firstName"] = firstName;
    data["lastName"] = lastName;
    
    if (!phoneNumber.isEmpty()) {
        data["phoneNumber"] = phoneNumber;
    }
    
    sendPostRequest("/auth/signup", data, "signup");
}

void ApiClient::login(const QString &email, const QString &password)
{
    QJsonObject data;
    data["email"] = email;
    data["password"] = password;
    
    sendPostRequest("/auth/login", data, "login");
}

void ApiClient::getCurrentUser()
{
    sendGetRequest("/auth/me", "getCurrentUser");
}

void ApiClient::logout()
{
    clearAuthToken();
    emit logoutSuccess();
}

void ApiClient::setAuthToken(const QString &token)
{
    m_authToken = token;
}

QString ApiClient::getAuthToken() const
{
    return m_authToken;
}

void ApiClient::clearAuthToken()
{
    m_authToken.clear();
}

QNetworkRequest ApiClient::createRequest(const QString &endpoint, bool requiresAuth)
{
    QUrl url(m_baseUrl + endpoint);
    QNetworkRequest request(url);
    
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    if (requiresAuth && !m_authToken.isEmpty()) {
        request.setRawHeader("Authorization", 
                           QString("Bearer %1").arg(m_authToken).toUtf8());
    }
    
    return request;
}

void ApiClient::sendPostRequest(const QString &endpoint, const QJsonObject &data,
                                const QString &requestType)
{
    QNetworkRequest request = createRequest(endpoint, false);
    
    QJsonDocument doc(data);
    QByteArray jsonData = doc.toJson();
    
    QNetworkReply *reply = m_networkManager->post(request, jsonData);
    reply->setProperty("requestType", requestType);
}

void ApiClient::sendGetRequest(const QString &endpoint, const QString &requestType)
{
    QNetworkRequest request = createRequest(endpoint, true);
    
    QNetworkReply *reply = m_networkManager->get(request);
    reply->setProperty("requestType", requestType);
}

void ApiClient::onNetworkReply(QNetworkReply *reply)
{
    reply->deleteLater();
    
    QString requestType = reply->property("requestType").toString();
    
    if (reply->error() != QNetworkReply::NoError) {
        QString errorMsg = reply->errorString();
        
        if (requestType == "signup") {
            emit signupError(errorMsg);
        } else if (requestType == "login") {
            emit loginError(errorMsg);
        } else if (requestType == "getCurrentUser") {
            emit userDataError(errorMsg);
        }
        return;
    }
    
    QByteArray responseData = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(responseData);
    QJsonObject response = doc.object();
    
    bool success = response["success"].toBool();
    QString message = response["message"].toString();
    
    if (!success) {
        if (requestType == "signup") {
            emit signupError(message);
        } else if (requestType == "login") {
            emit loginError(message);
        } else if (requestType == "getCurrentUser") {
            emit userDataError(message);
        }
        return;
    }
    
    QJsonObject data = response["data"].toObject();
    
    if (requestType == "signup") {
        QJsonObject user = data["user"].toObject();
        QString token = data["token"].toString();
        setAuthToken(token);
        emit signupSuccess(user, token);
        
    } else if (requestType == "login") {
        QJsonObject user = data["user"].toObject();
        QString token = data["token"].toString();
        setAuthToken(token);
        emit loginSuccess(user, token);
        
    } else if (requestType == "getCurrentUser") {
        QJsonObject user = data["user"].toObject();
        emit userDataReceived(user);
    }
}
```

---

### 4. Usage Example in Your Qt Application

```cpp
#include "ApiClient.h"
#include <QDebug>

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr)
        : QMainWindow(parent)
        , m_apiClient(new ApiClient(this))
    {
        // Connect signals
        connect(m_apiClient, &ApiClient::loginSuccess,
                this, &MainWindow::onLoginSuccess);
        connect(m_apiClient, &ApiClient::loginError,
                this, &MainWindow::onLoginError);
        
        connect(m_apiClient, &ApiClient::signupSuccess,
                this, &MainWindow::onSignupSuccess);
        connect(m_apiClient, &ApiClient::signupError,
                this, &MainWindow::onSignupError);
    }

private slots:
    void onLoginButtonClicked()
    {
        QString email = ui->emailLineEdit->text();
        QString password = ui->passwordLineEdit->text();
        
        m_apiClient->login(email, password);
    }
    
    void onSignupButtonClicked()
    {
        QString email = ui->emailLineEdit->text();
        QString password = ui->passwordLineEdit->text();
        QString firstName = ui->firstNameLineEdit->text();
        QString lastName = ui->lastNameLineEdit->text();
        
        m_apiClient->signup(email, password, firstName, lastName);
    }
    
    void onLoginSuccess(const QJsonObject &userData, const QString &token)
    {
        qDebug() << "Login successful!";
        qDebug() << "User ID:" << userData["id"].toString();
        qDebug() << "Email:" << userData["email"].toString();
        qDebug() << "Token:" << token;
        
        // Save token for future requests
        // You might want to save this to QSettings
        QSettings settings;
        settings.setValue("authToken", token);
        
        // Navigate to main application screen
        // ...
    }
    
    void onLoginError(const QString &errorMessage)
    {
        qDebug() << "Login failed:" << errorMessage;
        QMessageBox::warning(this, "Login Failed", errorMessage);
    }
    
    void onSignupSuccess(const QJsonObject &userData, const QString &token)
    {
        qDebug() << "Signup successful!";
        // Automatically log in or show success message
    }
    
    void onSignupError(const QString &errorMessage)
    {
        qDebug() << "Signup failed:" << errorMessage;
        QMessageBox::warning(this, "Signup Failed", errorMessage);
    }

private:
    ApiClient *m_apiClient;
};
```

---

### 5. Persistent Token Storage

```cpp
// Save token after login
void saveAuthToken(const QString &token)
{
    QSettings settings("YourCompany", "TalklessApp");
    settings.setValue("authToken", token);
}

// Load token on app startup
QString loadAuthToken()
{
    QSettings settings("YourCompany", "TalklessApp");
    return settings.value("authToken", QString()).toString();
}

// Clear token on logout
void clearAuthToken()
{
    QSettings settings("YourCompany", "TalklessApp");
    settings.remove("authToken");
}

// Usage in main application
void MainWindow::initializeApp()
{
    QString savedToken = loadAuthToken();
    if (!savedToken.isEmpty()) {
        m_apiClient->setAuthToken(savedToken);
        // Verify token is still valid
        m_apiClient->getCurrentUser();
    } else {
        // Show login screen
        showLoginDialog();
    }
}
```

---

## API Response Examples

### Signup Response
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": "uuid-here",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "emailVerified": false,
      "isActive": true
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### Login Response
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": { /* same as signup */ },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### Error Response
```json
{
  "success": false,
  "message": "Invalid email or password",
  "errors": null
}
```

---

## Password Requirements

- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

---

## Testing

### Test the API from Qt
```cpp
void testConnection()
{
    QNetworkAccessManager manager;
    QNetworkRequest request(QUrl("https://talkless-backend.vercel.app/api/health"));
    
    QNetworkReply *reply = manager.get(request);
    
    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();
    
    qDebug() << "Response:" << reply->readAll();
}
```

---

## Security Best Practices

1. **Never hardcode credentials** in your application
2. **Store tokens securely** using QSettings or platform keychain
3. **Clear tokens on logout**
4. **Validate SSL certificates** (Qt does this by default)
5. **Handle token expiration** (tokens expire after 24 hours)

---

## Troubleshooting

### SSL Certificate Errors
If you encounter SSL errors, ensure Qt has access to system certificates:
```cpp
QSslConfiguration config = QSslConfiguration::defaultConfiguration();
config.setPeerVerifyMode(QSslSocket::VerifyPeer);
QSslConfiguration::setDefaultConfiguration(config);
```

### CORS Issues
The backend is configured to accept requests from any origin. If you still face CORS issues, ensure you're making requests from the application (not a web browser).

---

## Domain Information

**Production Domain**: `talkless-backend.vercel.app`

**Full API URL**: `https://talkless-backend.vercel.app/api`

**Vercel Project**: `adlahirus-projects/talkless-backend`

---

## Rate Limits

- **Login**: 5 attempts per 15 minutes per IP
- **Signup**: 3 attempts per hour per IP
- **General API**: 100 requests per 15 minutes per IP

---

## Support

For backend issues or API questions, check the main [README.md](./README.md) or the [walkthrough documentation](../brain/904e5dc5-d4ba-4eaa-8efe-2566f127220e/walkthrough.md).
