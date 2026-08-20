"""Кастомный security manager: разбор JWT из ответа ADFS OIDC для маппинга пользователя и ролей."""

from superset.security import SupersetSecurityManager


class CustomSsoSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == "SSO":
            id_token = response.get("access_token")
            if not id_token:
                return {}

            from jwt import decode as jwt_decode

            decoded = jwt_decode(id_token, options={"verify_signature": False})
            adfs_roles = decoded.get("roles", [])
            return {
                "name": decoded.get("dname", ""),
                "email": decoded.get("email", ""),
                "id": decoded.get("guid", ""),
                "username": decoded.get("upn", ""),
                "first_name": decoded.get("firstname", ""),
                "last_name": decoded.get("lastname", ""),
                "role_keys": adfs_roles,
            }
        return super().oauth_user_info(provider, response)
