import { Component } from '@angular/core';

@Component({
  selector: 'app-footer',
  standalone: true,
  templateUrl: './footer.component.html',
  styleUrl: './footer.component.scss'
})
export class FooterComponent {
  showTerms = false;
  showPrivacy = false;

  openTerms() { this.showTerms = true; }
  closeTerms() { this.showTerms = false; }
  openPrivacy() { this.showPrivacy = true; }
  closePrivacy() { this.showPrivacy = false; }
}
