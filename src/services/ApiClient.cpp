#include "ApiClient.h"

#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QUrlQuery>

ApiClient::ApiClient(QObject* parent)
    : QObject(parent), m_networkManager(new QNetworkAccessManager(this)),
      m_baseUrl("https://talkless-backend.vercel.app/api")
{
    connect(m_networkManager, &QNetworkAccessManager::finished, this, &ApiClient::onNetworkReply);
}

void ApiClient::signup(const QString& email, const QString& password, const QString& firstName, const QString& lastName,
                       const QString& phoneNumber)
{
    setLoading(true);
    setError("");

    QJsonObject data;
    data["email"] = email;
    data["password"] = password;
    data["firstName"] = firstName;
    data["lastName"] = lastName;

    if (!phoneNumber.isEmpty()) {
        data["phoneNumber"] = phoneNumber;
    }

    qDebug() << "[ApiClient] Sending signup request for:" << email;
    sendPostRequest("/auth/signup", data, "signup");
}

void ApiClient::login(const QString& email, const QString& password, bool rememberMe)
{
    setLoading(true);
    setError("");

    m_rememberMe = rememberMe;

    QJsonObject data;
    data["email"] = email;
    data["password"] = password;

    qDebug() << "[ApiClient] Sending login request for:" << email << "Remember me:" << rememberMe;
    sendPostRequest("/auth/login", data, "login");
}

void ApiClient::loginAsGuest()
{
    qDebug() << "[ApiClient] Logging in as guest";

    // Clear any existing data
    clearAuthToken();
    clearUserData();

    // Set guest state
    m_firstName = "Guest";
    m_lastName = "";
    m_email = "";
    m_userId = "";
    m_rememberMe = false;

    setLoggedIn(true, true);
    emit loginSuccess();
    emit currentUserChanged();
}

void ApiClient::logout()
{
    qDebug() << "[ApiClient] Logging out";

    clearAuthToken();
    clearUserData();

    m_firstName = "";
    m_lastName = "";
    m_email = "";
    m_userId = "";

    setLoggedIn(false);
    emit logoutSuccess();
}

void ApiClient::checkSavedSession()
{
    qDebug() << "[ApiClient] Checking for saved session";

    QString savedToken = loadAuthToken();
    if (savedToken.isEmpty()) {
        qDebug() << "[ApiClient] No saved token found";
        emit sessionInvalid();
        return;
    }

    m_authToken = savedToken;
    loadUserData();

    // Verify token is still valid by calling /auth/me
    setLoading(true);
    sendGetRequest("/auth/me", "checkSession");
}

QNetworkRequest ApiClient::createRequest(const QString& endpoint, bool requiresAuth)
{
    QUrl url(m_baseUrl + endpoint);
    QNetworkRequest request(url);

    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    if (requiresAuth && !m_authToken.isEmpty()) {
        request.setRawHeader("Authorization", QString("Bearer %1").arg(m_authToken).toUtf8());
    }

    return request;
}

void ApiClient::sendPostRequest(const QString& endpoint, const QJsonObject& data, const QString& requestType)
{
    QNetworkRequest request = createRequest(endpoint, false);

    QJsonDocument doc(data);
    QByteArray jsonData = doc.toJson();

    QNetworkReply* reply = m_networkManager->post(request, jsonData);
    reply->setProperty("requestType", requestType);
}

void ApiClient::sendGetRequest(const QString& endpoint, const QString& requestType)
{
    QNetworkRequest request = createRequest(endpoint, true);

    QNetworkReply* reply = m_networkManager->get(request);
    reply->setProperty("requestType", requestType);
}

void ApiClient::onNetworkReply(QNetworkReply* reply)
{
    reply->deleteLater();
    setLoading(false);

    QString requestType = reply->property("requestType").toString();

    // Check for network errors
    if (reply->error() != QNetworkReply::NoError) {
        QString errorMsg = reply->errorString();
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        qDebug() << "[ApiClient] Network error for" << requestType << ":" << errorMsg << "Status:" << statusCode;

        if (statusCode == 429) {
            errorMsg = "Too many attempts. Please try again later.";
        }

        // Try to parse error from response body
        QByteArray responseData = reply->readAll();
        if (!responseData.isEmpty()) {
            QJsonDocument doc = QJsonDocument::fromJson(responseData);
            if (doc.isObject()) {
                QJsonObject response = doc.object();
                QString serverMessage = response["message"].toString();

                // Parse specific validation errors if available
                if (response.contains("errors") && response["errors"].isArray()) {
                    QJsonArray errors = response["errors"].toArray();
                    QStringList errorDetails;
                    for (const auto value : errors) {
                        QJsonObject error = value.toObject();
                        if (error.contains("message")) {
                            errorDetails << error["message"].toString();
                        }
                    }

                    if (!errorDetails.isEmpty()) {
                        if (!serverMessage.isEmpty()) {
                            serverMessage += ":\n" + errorDetails.join("\n");
                        } else {
                            serverMessage = errorDetails.join("\n");
                        }
                    }
                }

                if (!serverMessage.isEmpty()) {
                    errorMsg = serverMessage;
                }
            }
        }

        setError(errorMsg);

        if (requestType == "signup") {
            emit signupError(errorMsg);
        } else if (requestType == "login") {
            emit loginError(errorMsg);
        } else if (requestType == "checkSession") {
            clearAuthToken();
            clearUserData();
            emit sessionInvalid();
        }
        return;
    }

    QByteArray responseData = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(responseData);
    QJsonObject response = doc.object();

    bool success = response["success"].toBool();
    QString message = response["message"].toString();

    qDebug() << "[ApiClient] Response for" << requestType << "- success:" << success << ", message:" << message;

    if (!success) {
        setError(message);

        if (requestType == "signup") {
            emit signupError(message);
        } else if (requestType == "login") {
            emit loginError(message);
        } else if (requestType == "checkSession") {
            clearAuthToken();
            clearUserData();
            emit sessionInvalid();
        }
        return;
    }

    QJsonObject data = response["data"].toObject();

    if (requestType == "signup") {
        QJsonObject user = data["user"].toObject();
        QString token = data["token"].toString();

        m_authToken = token;
        saveAuthToken(token);
        setUserData(user);
        setLoggedIn(true, false);

        qDebug() << "[ApiClient] Signup successful for:" << m_email;
        emit signupSuccess();

    } else if (requestType == "login") {
        QJsonObject user = data["user"].toObject();
        QString token = data["token"].toString();

        m_authToken = token;

        // Only save persistence data if "Remember Me" was checked
        if (m_rememberMe) {
            saveAuthToken(token);
        } else {
            clearAuthToken(); // Ensure no old token persists
        }

        setUserData(user);
        setLoggedIn(true, false);

        qDebug() << "[ApiClient] Login successful for:" << m_email;
        emit loginSuccess();

    } else if (requestType == "checkSession") {
        QJsonObject user = data["user"].toObject();
        setUserData(user);
        setLoggedIn(true, false);

        qDebug() << "[ApiClient] Session restored for:" << m_email;
        emit sessionRestored();
    }
}

// Token persistence
void ApiClient::saveAuthToken(const QString& token)
{
    QSettings settings("TalkLess", "TalkLessApp");
    settings.setValue("auth/token", token);
    qDebug() << "[ApiClient] Auth token saved";
}

QString ApiClient::loadAuthToken()
{
    QSettings settings("TalkLess", "TalkLessApp");
    return settings.value("auth/token", QString()).toString();
}

void ApiClient::clearAuthToken()
{
    QSettings settings("TalkLess", "TalkLessApp");
    settings.remove("auth/token");
    m_authToken.clear();
    qDebug() << "[ApiClient] Auth token cleared";
}

// User data persistence
void ApiClient::saveUserData()
{
    QSettings settings("TalkLess", "TalkLessApp");
    settings.setValue("user/firstName", m_firstName);
    settings.setValue("user/lastName", m_lastName);
    settings.setValue("user/email", m_email);
    settings.setValue("user/id", m_userId);
    settings.setValue("user/isGuest", m_isGuest);
}

void ApiClient::loadUserData()
{
    QSettings settings("TalkLess", "TalkLessApp");
    m_firstName = settings.value("user/firstName", QString()).toString();
    m_lastName = settings.value("user/lastName", QString()).toString();
    m_email = settings.value("user/email", QString()).toString();
    m_userId = settings.value("user/id", QString()).toString();
    m_isGuest = settings.value("user/isGuest", false).toBool();
}

void ApiClient::clearUserData()
{
    QSettings settings("TalkLess", "TalkLessApp");
    settings.remove("user/firstName");
    settings.remove("user/lastName");
    settings.remove("user/email");
    settings.remove("user/id");
    settings.remove("user/isGuest");
}

// State setters
void ApiClient::setLoading(bool loading)
{
    if (m_isLoading != loading) {
        m_isLoading = loading;
        emit isLoadingChanged();
    }
}

void ApiClient::setError(const QString& error)
{
    if (m_errorMessage != error) {
        m_errorMessage = error;
        emit errorMessageChanged();
    }
}

void ApiClient::setLoggedIn(bool loggedIn, bool isGuest)
{
    bool loggedInChanged = m_isLoggedIn != loggedIn;
    bool guestChanged = m_isGuest != isGuest;

    m_isLoggedIn = loggedIn;
    m_isGuest = isGuest;

    if (loggedIn && m_rememberMe) {
        saveUserData();
    } else if (loggedIn && !m_rememberMe) {
        // If logged in but not remembering, ensure user data is cleared from disk
        // (It stays in memory variables via setUserData)
        clearUserData();
    }

    if (loggedInChanged) {
        emit isLoggedInChanged();
    }
    if (guestChanged) {
        emit isGuestChanged();
    }
}

void ApiClient::setUserData(const QJsonObject& userData)
{
    m_userId = userData["id"].toString();
    m_email = userData["email"].toString();
    m_firstName = userData["firstName"].toString();
    m_lastName = userData["lastName"].toString();

    qDebug() << "[ApiClient] User data set - firstName:" << m_firstName << ", lastName:" << m_lastName
             << ", email:" << m_email;

    emit currentUserChanged();
}
