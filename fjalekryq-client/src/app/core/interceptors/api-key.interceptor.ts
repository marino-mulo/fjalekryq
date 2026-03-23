import { HttpInterceptorFn } from '@angular/common/http';

const API_KEY = 'LL-k9x2mP7vR4wQ8jN5tB3yF6hA1dE0cU';

export const apiKeyInterceptor: HttpInterceptorFn = (req, next) => {
  const cloned = req.clone({
    setHeaders: { 'X-Api-Key': API_KEY }
  });
  return next(cloned);
};
